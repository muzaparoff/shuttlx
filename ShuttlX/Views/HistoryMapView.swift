import SwiftUI
import MapKit
import ShuttlXShared

/// Map mode of History: route polylines of the given sessions (the month
/// chosen in HistoryView), sport filter chips, session sheet, "Same route" list.
struct HistoryMapView: View {
    let sessions: [TrainingSession]
    @State private var sport: WorkoutSport?
    @State private var selectedID: UUID?
    @State private var sheetSession: TrainingSession?

    private var routed: [TrainingSession] {
        sessions.filter { ($0.route?.count ?? 0) >= 2 && (sport == nil || $0.sportType == sport) }
    }

    private var sports: [WorkoutSport] {
        let present = Set(sessions.filter { ($0.route?.count ?? 0) >= 2 }.compactMap(\.sportType))
        return WorkoutSport.allCases.filter(present.contains)
    }

    var body: some View {
        VStack(spacing: 16) {
            if sports.count > 1 { chips }

            if routed.isEmpty {
                Text("No routes this month")
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
            } else {
                Map(selection: $selectedID) {
                    ForEach(routed) { s in
                        MapPolyline(coordinates: coords(s))
                            .stroke(ShuttlXColor.ctaPrimary, lineWidth: selectedID == s.id ? 6 : 3)
                            .tag(s.id)
                        if let first = coords(s).first {
                            Marker(s.displayName, coordinate: first).tint(ShuttlXColor.ctaPrimary).tag(s.id)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .frame(height: 340)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .accessibilityLabel("Map of \(routed.count) routes")

                sameRoutes
            }
        }
        .onChange(of: selectedID) { _, id in
            sheetSession = routed.first { $0.id == id }
        }
        .sheet(item: $sheetSession, onDismiss: { selectedID = nil }) { s in
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    SessionRowView(session: s)
                    NavigationLink(destination: SessionDetailView(session: s)) {
                        Text("Open session").font(ShuttlXFont.cardTitle)
                    }
                    .accessibilityHint("Shows full session details")
                    Spacer()
                }
                .padding()
                .themedScreenBackground()
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Chips

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", icon: nil, on: sport == nil) { sport = nil }
                ForEach(sports) { sp in
                    chip(sp.displayName, icon: sp.systemImage, on: sport == sp) { sport = sp }
                }
            }
            .padding(.horizontal)
        }
    }

    private func chip(_ title: String, icon: String?, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(ShuttlXFont.cardCaption)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .foregroundStyle(on ? Color.white : Color.primary)
            .background(on ? ShuttlXColor.ctaPrimary : ShuttlXColor.surface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: - Same route

    /// ponytail: greedy single-pass grouping against each group's first
    /// session (start within 150 m, distance within 15%); fine for a month of
    /// sessions, switch to proper clustering if groups drift.
    private var sameRouteGroups: [[TrainingSession]] {
        var groups: [[TrainingSession]] = []
        for s in routed {
            guard let start = coords(s).first, let d = s.distance, d > 0 else { continue }
            let here = CLLocation(latitude: start.latitude, longitude: start.longitude)
            if let i = groups.firstIndex(where: { g in
                guard let ref = g.first, let rs = coords(ref).first, let rd = ref.distance else { return false }
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

    @ViewBuilder
    private var sameRoutes: some View {
        let groups = sameRouteGroups
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(groups.indices, id: \.self) { i in
                    let g = groups[i]
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Same route · \(g.count)×")
                            .font(ShuttlXFont.sectionHeader)
                        Text(FormattingUtils.formatDistance(g[0].distance ?? 0))
                            .font(ShuttlXFont.cardCaption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        ForEach(g) { s in
                            NavigationLink(destination: SessionDetailView(session: s)) {
                                HStack {
                                    Text(s.startDate.formatted(.dateTime.month(.abbreviated).day()))
                                    Spacer()
                                    Text(FormattingUtils.formatDuration(s.duration)).monospacedDigit()
                                }
                                .font(ShuttlXFont.cardCaption)
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(s.displayName), \(s.startDate.formatted(date: .abbreviated, time: .omitted))")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .themedCard()
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Polyline coordinates (decimated; month of raw GPS is heavy)

    private func coords(_ s: TrainingSession) -> [CLLocationCoordinate2D] {
        let r = s.route ?? []
        let step = max(1, r.count / 200)
        var out = stride(from: 0, to: r.count, by: step).map {
            CLLocationCoordinate2D(latitude: r[$0].latitude, longitude: r[$0].longitude)
        }
        if let l = r.last, step > 1 {
            out.append(CLLocationCoordinate2D(latitude: l.latitude, longitude: l.longitude))
        }
        return out
    }
}
