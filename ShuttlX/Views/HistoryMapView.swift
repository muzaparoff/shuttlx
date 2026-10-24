import SwiftUI
import MapKit
import ShuttlXShared

/// One coloured stretch of a session's route (a run of consecutive GPS points with the same effective activity).
private struct RoutePiece: Identifiable {
    let id: String
    let sessionID: UUID
    let activity: DetectedActivity
    let coords: [CLLocationCoordinate2D]
}

/// "km 5 / 5'48"/km" (or mi) label on the selected route.
private struct KmMark: Identifiable {
    let id: Int
    let coord: CLLocationCoordinate2D
    let km: Int
    let pace: String?
}

/// Map mode of History (approved mockup, 2026-10): full-bleed map of every route in
/// the chosen month, floating chips filtering by detected activity, a bottom sheet
/// listing the trainings, and a selected-route state with "Open details" / "Same route".
struct HistoryMapView: View {
    let sessions: [TrainingSession]
    @Binding var mode: HistoryMode
    @Binding var month: Date

    @State private var filter: DetectedActivity?
    @State private var selectedID: UUID?
    @State private var position: MapCameraPosition = .automatic
    @State private var hybrid = false
    @State private var expanded = false
    @State private var showLaps = false
    @EnvironmentObject private var dataManager: DataManager
    /// Polylines are expensive (activity lookup per point); rebuilt only when the sessions, filter or edits change.
    @State private var pieceCache: [RoutePiece] = []

    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 58
    @Environment(\.dynamicTypeSize) private var typeSize
    private static let locationManager = CLLocationManager()
    private let filterable: [DetectedActivity] = [.running, .walking, .cycling]

    // MARK: - Data

    private func effectiveActivities(_ s: TrainingSession) -> Set<DetectedActivity> {
        Set(s.displaySegments().map(\.activityType))
    }

    /// Sessions that pass the chip filter (matched on the DETECTED activity, overrides included).
    private var visible: [TrainingSession] {
        guard let filter else { return sessions }
        return sessions.filter { effectiveActivities($0).contains(filter) }
    }

    private func hasRoute(_ s: TrainingSession) -> Bool { (s.inlineRoute?.count ?? 0) >= 2 }

    private var routed: [TrainingSession] { visible.filter(hasRoute) }

    private var selected: TrainingSession? { routed.first { $0.id == selectedID } }

    private func rebuildPieces() {
        pieceCache = routed.flatMap { pieces(for: $0) }.filter { filter == nil || $0.activity == filter }
    }

    /// Splits the (decimated) route by the effective activity at each point's timestamp.
    private func pieces(for s: TrainingSession) -> [RoutePiece] {
        guard let route = s.inlineRoute, route.count >= 2 else { return [] }
        let segs = s.displaySegments()
        let step = max(1, route.count / 200)
        var idx = Array(stride(from: 0, to: route.count, by: step))
        if idx.last != route.count - 1 { idx.append(route.count - 1) }

        func activity(at t: Date) -> DetectedActivity {
            (segs.first { t >= $0.startDate && t <= ($0.endDate ?? .distantFuture) } ?? segs.last)?.activityType ?? .running
        }
        func coord(_ i: Int) -> CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: route[i].latitude, longitude: route[i].longitude)
        }

        var out: [RoutePiece] = []
        var cur: [CLLocationCoordinate2D] = []
        var curActivity = activity(at: route[idx[0]].timestamp)
        for i in idx {
            let a = activity(at: route[i].timestamp)
            if a != curActivity, !cur.isEmpty {
                cur.append(coord(i))   // keep the line continuous across the switch
                out.append(RoutePiece(id: "\(s.id)-\(out.count)", sessionID: s.id, activity: curActivity, coords: cur))
                cur = []
                curActivity = a
            }
            cur.append(coord(i))
        }
        if cur.count >= 2 { out.append(RoutePiece(id: "\(s.id)-\(out.count)", sessionID: s.id, activity: curActivity, coords: cur)) }
        return out
    }

    /// ponytail: greedy single-pass grouping against each group's first
    /// session (start within 150 m, distance within 15%); fine for a month of
    /// sessions, switch to proper clustering if groups drift.
    private var sameRouteGroups: [[TrainingSession]] {
        var groups: [[TrainingSession]] = []
        for s in routed {
            guard let start = s.inlineRoute?.first, let d = s.distance, d > 0 else { continue }
            let here = CLLocation(latitude: start.latitude, longitude: start.longitude)
            if let i = groups.firstIndex(where: { g in
                guard let ref = g.first, let rs = ref.inlineRoute?.first, let rd = ref.distance else { return false }
                return here.distance(from: CLLocation(latitude: rs.latitude, longitude: rs.longitude)) <= 150
                    && abs(d - rd) <= 0.15 * rd
            }) {
                groups[i].append(s)
            } else {
                groups.append([s])
            }
        }
        return groups.filter { $0.count > 1 }
    }

    private func color(_ a: DetectedActivity) -> Color { a.themeColor }

    /// A label every km (every 2nd, 5th... on long routes, so at most ~10 show), built from the GPS points' timestamps.
    /// Pace is the time since the previous label, shown unless the whole session is cycling.
    private func kmMarks(_ s: TrainingSession) -> [KmMark] {
        guard let route = s.inlineRoute, route.count >= 2 else { return [] }
        let unit = DistanceUnit.current
        let total = unit.value(fromKm: s.distance ?? 0)
        let stepKm = max(1, Int((total / 10).rounded(.up)))
        let showPace = !s.displaySegments().allSatisfy { $0.activityType == .cycling }
        var out: [KmMark] = []
        var metres = 0.0
        var nextKm = stepKm
        var lastTime = route[0].timestamp
        var prev = CLLocation(latitude: route[0].latitude, longitude: route[0].longitude)
        for p in route.dropFirst() {
            let here = CLLocation(latitude: p.latitude, longitude: p.longitude)
            metres += here.distance(from: prev)
            prev = here
            if metres >= Double(nextKm) * 1000 * unit.km {
                let secPerKm = p.timestamp.timeIntervalSince(lastTime) / (Double(stepKm) * unit.km)
                out.append(KmMark(id: nextKm, coord: CLLocationCoordinate2D(latitude: p.latitude, longitude: p.longitude),
                                  km: nextKm, pace: showPace && secPerKm > 0 ? FormattingUtils.formatPaceWithUnit(secPerKm, unit: .current) : nil))
                lastTime = p.timestamp
                nextKm += stepKm
            }
        }
        return out
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            map.ignoresSafeArea()
            header
            VStack { Spacer(); sheet }
        }
        .onAppear {
            #if DEBUG
            // Screenshot seam: SHUTTLX_HISTORY_SELECT=<n> selects the nth routed session.
            if let raw = ProcessInfo.processInfo.environment["SHUTTLX_HISTORY_SELECT"], let n = Int(raw),
               routed.indices.contains(n) { selectedID = routed[n].id }
            #endif
            rebuildPieces()
            fit()
        }
        .onChange(of: sessions.map(\.id)) { _, _ in selectedID = nil; rebuildPieces(); fit() }
        .onChange(of: filter) { _, _ in selectedID = nil; rebuildPieces(); fit() }
        .onChange(of: dataManager.effectiveVersion) { _, _ in rebuildPieces() }
        .onChange(of: selectedID) { _, _ in showLaps = false; fit() }
        .accessibilityElement(children: .contain)
    }

    private var map: some View {
        let all = pieceCache
        let dim = selectedID != nil
        return Map(position: $position, selection: $selectedID) {
            UserAnnotation()
            ForEach(all.filter { $0.sessionID != selectedID }) { p in
                MapPolyline(coordinates: p.coords)
                    .stroke(color(p.activity).opacity(dim ? 0.4 : 0.55), lineWidth: 3)
                    .tag(p.sessionID)
            }
            ForEach(all.filter { $0.sessionID == selectedID }) { p in
                MapPolyline(coordinates: p.coords).stroke(.white, lineWidth: 9)
            }
            ForEach(all.filter { $0.sessionID == selectedID }) { p in
                MapPolyline(coordinates: p.coords).stroke(color(p.activity), lineWidth: 5)
            }
            if let s = selected {
                ForEach(kmMarks(s)) { m in
                    Annotation("", coordinate: m.coord, anchor: .bottom) {
                        VStack(spacing: 0) {
                            Text("\(DistanceUnit.current.symbol) \(m.km)").font(ShuttlXFont.microLabel.weight(.bold))
                            if let pace = m.pace { Text(pace).font(ShuttlXFont.microLabel) }
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .accessibilityLabel("\(DistanceUnit.current.name.capitalized) \(m.km)" + (m.pace.map { ", pace \($0)" } ?? ""))
                    }
                }
            }
            if let start = selected?.inlineRoute?.first {
                Annotation("Start", coordinate: CLLocationCoordinate2D(latitude: start.latitude, longitude: start.longitude), anchor: .center) {
                    Circle().fill(ShuttlXColor.running).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .mapStyle(hybrid ? .hybrid(elevation: .flat) : .standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls { }
        .accessibilityLabel("Map of \(routed.count) routes")
    }

    // MARK: - Floating header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if selected != nil {
                Button { selectedID = nil } label: {
                    HStack(spacing: 4) { Image(systemName: "chevron.left"); Text("All trainings") }
                        .font(ShuttlXFont.cardCaption.weight(.semibold))
                        .foregroundStyle(ShuttlXColor.textPrimary)
                        .padding(.horizontal, 12).frame(minHeight: 32)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.leading, 14)
                .accessibilityLabel("Back to all trainings")
            } else {
                HistoryModePicker(mode: $mode)
                    .padding(2)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 16)
                chips
                HStack(alignment: .top) {
                    periodMenu
                    Spacer()
                    VStack(spacing: 8) {
                        fab("square.3.layers.3d", label: hybrid ? "Standard map" : "Satellite map") { hybrid.toggle() }
                        fab("location", label: "Show my location") {
                            Self.locationManager.requestWhenInUseAuthorization()
                            position = .userLocation(fallback: .automatic)
                        }
                    }
                }
                .padding(.horizontal, 14)
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip("All", dot: nil, on: filter == nil) { filter = nil }
                ForEach(filterable, id: \.self) { a in
                    chip(TodayFormat.activityName(a), dot: color(a), on: filter == a) { filter = a }
                }
            }
            .padding(.horizontal, 14)
        }
    }

    private func chip(_ title: String, dot: Color?, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let dot { Circle().fill(dot).frame(width: 9, height: 9) }
                Text(title)
            }
            .font(ShuttlXFont.cardCaption.weight(.semibold))
            .foregroundStyle(on ? ShuttlXColor.iconOnCTA : ShuttlXColor.textPrimary)
            .padding(.horizontal, 12).frame(minHeight: 32)
            .background(on ? AnyShapeStyle(ShuttlXColor.ctaPrimary) : AnyShapeStyle(.regularMaterial), in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var periodMenu: some View {
        let cal = Calendar.current
        let months: [Date] = (0..<12).compactMap { cal.date(byAdding: .month, value: -$0, to: Date()) }
        return Menu {
            ForEach(months, id: \.self) { m in
                Button(m.formatted(.dateTime.month(.wide).year())) { month = m }
            }
        } label: {
            HStack(spacing: 4) {
                Text(month.formatted(.dateTime.month(.wide)))
                Image(systemName: "chevron.down").font(ShuttlXFont.microLabel.weight(.bold))
            }
            .font(ShuttlXFont.cardCaption.weight(.semibold))
            .foregroundStyle(ShuttlXColor.textPrimary)
            .padding(.horizontal, 12).frame(minHeight: 32)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
        }
        .accessibilityLabel("Period, \(month.formatted(.dateTime.month(.wide).year()))")
    }

    private func fab(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(ShuttlXFont.cardSubtitle)
                .foregroundStyle(ShuttlXColor.textPrimary)
                .frame(minWidth: 44, minHeight: 44)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Camera

    /// Frames `list` in the free band between the floating header and the sheet.
    private func fit() {
        let list = selected.map { [$0] } ?? routed
        var rect = MKMapRect.null
        for s in list {
            for p in s.inlineRoute ?? [] {
                let pt = MKMapPoint(CLLocationCoordinate2D(latitude: p.latitude, longitude: p.longitude))
                rect = rect.union(MKMapRect(origin: pt, size: MKMapSize(width: 0, height: 0)))
            }
        }
        guard !rect.isNull else { position = .automatic; return }
        let aspect = 0.46                                   // phone width / height
        let usable = selected == nil ? 0.38 : 0.42           // share of screen height left by header + sheet
        let h = max(rect.height * 1.35 / usable, rect.width * 1.35 / aspect, 4000)
        let w = h * aspect
        let centerYShift = (0.5 - (selected == nil ? 0.40 : 0.38)) * h
        position = .rect(MKMapRect(x: rect.midX - w / 2, y: rect.midY + centerYShift - h / 2, width: w, height: h))
    }

    // MARK: - Bottom sheet

    private var sheet: some View {
        VStack(spacing: 8) {
            Capsule().fill(Color(.tertiaryLabel)).frame(width: 36, height: 5)
                .padding(.top, 6).padding(.bottom, 4)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.ifAllowed(.snappy)) { expanded.toggle() } }
                .gesture(DragGesture(minimumDistance: 12).onEnded { v in
                    withAnimation(.ifAllowed(.snappy)) { expanded = v.translation.height < 0 }
                })
                .accessibilityElement()
                .accessibilityLabel("Trainings sheet")
                .accessibilityHint(expanded ? "Collapses the list" : "Expands the list")
                .accessibilityAddTraits(.isButton)
            if let s = selected { detail(s) } else { list }
        }
        .padding(.bottom, 8)   // the tab bar already insets the safe area; the sheet background runs behind it
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.16), radius: 12, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var list: some View {
        let items = visible
        let km = items.compactMap(\.distance).reduce(0, +)
        let hours = items.reduce(0) { $0 + $1.duration } / 3600
        return VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) { listTitle(items.count); Spacer(); listTotals(km, hours) }
                VStack(alignment: .leading, spacing: 2) { listTitle(items.count); listTotals(km, hours) }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18).padding(.bottom, 4)
            .accessibilityElement(children: .combine)
            if items.isEmpty {
                Text("No trainings this month")
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(ShuttlXColor.textSecondary)
                    .padding(.vertical, 24)
            } else {
                // Height follows the rows (3 collapsed, 7 expanded) so none is clipped and nothing is left empty below.
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { s in row(s) }
                    }
                }
                .frame(height: CGFloat(min(items.count, typeSize.isAccessibilitySize ? 2 : (expanded ? 7 : 3))) * rowHeight)
            }
        }
    }

    private func listTitle(_ n: Int) -> some View {
        Text("\(n) training\(n == 1 ? "" : "s")")
            .font(ShuttlXFont.cardTitle.weight(.bold))
            .foregroundStyle(ShuttlXColor.textPrimary)
    }

    private func listTotals(_ km: Double, _ hours: Double) -> some View {
        Text("\(Int(DistanceUnit.current.value(fromKm: km).rounded())) \(DistanceUnit.current.symbol) \u{00B7} \(Int(hours.rounded())) h")
            .font(ShuttlXFont.cardCaption.monospacedDigit())
            .foregroundStyle(ShuttlXColor.textSecondary)
    }

    @ViewBuilder
    private func row(_ s: TrainingSession) -> some View {
        let segs = s.displaySegments()
        let big = typeSize.isAccessibilitySize
        let km: String? = s.distance.flatMap { $0 > 0 ? FormattingUtils.formatDistanceValue($0, unit: .current) + " " + DistanceUnit.current.symbol : nil }
        let content = HStack(spacing: 10) {
            if !big {
                Group {
                    if hasRoute(s) {
                        RouteThumbnail(session: s, segments: segs, size: RouteSnapshotCache.square)
                    } else {
                        ZStack {
                            Color(.tertiarySystemFill)
                            Image(systemName: (segs.first?.activityType ?? .running).systemImage)
                                .foregroundStyle(ShuttlXColor.textSecondary)
                        }
                    }
                }
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(s.timelineName)
                    .font(ShuttlXFont.cardSubtitle.weight(.semibold))
                    .foregroundStyle(ShuttlXColor.textPrimary)
                Text(dayLabel(s.startDate) + " \u{00B7} " + TodayFormat.clock(s.startDate))
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(ShuttlXColor.textSecondary)
                // At accessibility sizes the distance moves under the text so the name keeps the full width.
                if big, let km {
                    Text(km).font(ShuttlXFont.cardCaption.monospacedDigit()).foregroundStyle(ShuttlXColor.textSecondary)
                }
            }
            Spacer(minLength: 6)
            if !big, let km {
                Text(km)
                    .font(ShuttlXFont.cardCaption.monospacedDigit())
                    .foregroundStyle(ShuttlXColor.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: rowHeight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        if hasRoute(s) {
            Button { selectedID = s.id } label: { content }
                .buttonStyle(.plain)
                .accessibilityHint("Highlights the route on the map")
        } else {
            NavigationLink(destination: SessionDetailView(session: s)) { content }
                .buttonStyle(.plain)
        }
    }

    private func dayLabel(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInYesterday(d) { return "Yesterday" }
        return d.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    // MARK: - Selected route

    private func detail(_ s: TrainingSession) -> some View {
        let segs = s.displaySegments()
        let group = sameRouteGroups.first { $0.contains { $0.id == s.id } }
        return VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(s.timelineName)
                    .font(ShuttlXFont.metricMedium)
                    .foregroundStyle(ShuttlXColor.textPrimary)
                Spacer()
                Text(s.startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) + " \u{00B7} " + TodayFormat.clock(s.startDate))
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(ShuttlXColor.textSecondary)
            }
            .padding(.horizontal, 18)
            .accessibilityElement(children: .combine)

            let pace = paceStat(s, segs)
            HStack(alignment: .top) {
                trio(s.distance.flatMap { $0 > 0 ? FormattingUtils.formatDistanceValue($0, unit: .current) : nil } ?? "\u{2013}", DistanceUnit.current.symbol, "distance")
                trio(shortClock(s.duration), "", "time")
                trio(pace.value, pace.unit, pace.label)
            }
            .padding(.horizontal, 18)

            ActivityRibbon(segments: segs, height: 16).padding(.horizontal, 18)

            if showLaps, let group { laps(group) }

            HStack(spacing: 8) {
                NavigationLink(destination: SessionDetailView(session: s)) {
                    Text("Open details")
                        .font(ShuttlXFont.cardSubtitle.weight(.semibold))
                        .foregroundStyle(ShuttlXColor.iconOnCTA)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(ShuttlXColor.ctaPrimary, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                if let group {
                    Button { withAnimation(.ifAllowed(.snappy)) { showLaps.toggle() } } label: {
                        Text("Same route \u{00B7} \(group.count)\u{00D7}")
                            .font(ShuttlXFont.cardSubtitle.weight(.semibold))
                            .foregroundStyle(ShuttlXColor.accentText)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(ShuttlXColor.ctaPrimary.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Lists your other laps of this route")
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
        }
    }

    private func trio(_ value: String, _ unit: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(ShuttlXFont.metricMedium.monospacedDigit())
                if !unit.isEmpty { Text(unit).font(ShuttlXFont.cardCaption.weight(.semibold)).foregroundStyle(ShuttlXColor.textSecondary) }
            }
            .foregroundStyle(ShuttlXColor.textPrimary)
            .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(ShuttlXFont.cardCaption).foregroundStyle(ShuttlXColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value) \(unit)")
    }

    private func shortClock(_ t: TimeInterval) -> String {
        let m = Int(t / 60)
        return String(format: "%d:%02d", m / 60, m % 60)
    }

    /// Run pace from the run parts when there are some, else cycling speed, else overall pace.
    private func paceStat(_ s: TrainingSession, _ segs: [ActivitySegment]) -> (value: String, unit: String, label: String) {
        let run = segs.filter { $0.activityType == .running && ($0.distance ?? 0) > 0.05 }
        if !run.isEmpty {
            let km = run.compactMap(\.distance).reduce(0, +)
            let t = run.reduce(0) { $0 + $1.duration }
            return (FormattingUtils.formatPace(t / km, unit: .current), DistanceUnit.current.paceSuffix, "run pace")
        }
        if let d = s.distance, d > 0, s.duration > 0 {
            if segs.allSatisfy({ $0.activityType == .cycling }) {
                return (String(format: "%.1f", d / (s.duration / 3600) / DistanceUnit.current.km), DistanceUnit.current == .km ? "km/h" : "mph", "avg speed")
            }
            return (FormattingUtils.formatPace(s.duration / d, unit: .current), DistanceUnit.current.paceSuffix, "avg pace")
        }
        return ("\u{2013}", "", "pace")
    }

    private func laps(_ group: [TrainingSession]) -> some View {
        VStack(spacing: 0) {
            ForEach(group) { g in
                Button { selectedID = g.id } label: {
                    HStack {
                        Text(g.startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                            .foregroundStyle(ShuttlXColor.textPrimary)
                        Spacer()
                        Text(FormattingUtils.formatDuration(g.duration))
                        if let d = g.distance, d > 0 {
                            Text(FormattingUtils.formatPaceWithUnit(g.duration / d, unit: .current)).frame(width: 70, alignment: .trailing)
                        }
                    }
                    .font(ShuttlXFont.cardCaption.monospacedDigit())
                    .foregroundStyle(ShuttlXColor.textSecondary)
                    .fontWeight(g.id == selectedID ? .bold : .regular)
                    .padding(.horizontal, 18).frame(minHeight: 36)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(g.timelineName), \(g.startDate.formatted(date: .abbreviated, time: .omitted))")
            }
        }
    }
}
