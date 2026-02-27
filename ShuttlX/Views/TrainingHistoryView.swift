import SwiftUI
import Charts

enum HistoryViewMode: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
}

struct TrainingHistoryView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedDate = Date()
    @State private var viewMode: HistoryViewMode = .week

    private var filteredSessions: [TrainingSession] {
        let calendar = Calendar.current
        return dataManager.sessions.filter { session in
            switch viewMode {
            case .day:
                return calendar.isDate(session.startDate, inSameDayAs: selectedDate)
            case .week:
                return calendar.isDate(session.startDate, equalTo: selectedDate, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(session.startDate, equalTo: selectedDate, toGranularity: .month)
            }
        }.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Segmented picker
                    Picker("View Mode", selection: $viewMode) {
                        ForEach(HistoryViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .accessibilityLabel("Time period")
                    .accessibilityValue(viewMode.rawValue)

                    // Date navigation
                    if viewMode == .week || viewMode == .day {
                        WeekStripView(selectedDate: $selectedDate, sessions: dataManager.sessions)
                    } else {
                        monthNavigator
                    }

                    if filteredSessions.isEmpty {
                        emptyState
                    } else {
                        // Charts (week/month view only, when there's data)
                        if viewMode == .week || viewMode == .month {
                            chartsSection
                        }

                        // Metric summary
                        metricSummary

                        // Session list
                        sessionList
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("History")
        }
        .animation(.easeInOut(duration: 0.2), value: viewMode)
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        HStack {
            Button { changeDate(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }
            .accessibilityLabel("Previous month")

            Spacer()

            Text(monthLabel)
                .font(.headline)

            Spacer()

            Button { changeDate(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
            .accessibilityLabel("Next month")
        }
        .padding(.horizontal)
    }

    // MARK: - Charts Section

    private var chartsSection: some View {
        VStack(spacing: 12) {
            let summaries = dataManager.dailySummaries(days: viewMode == .week ? 7 : 30)

            if summaries.contains(where: { $0.totalDistance > 0 }) {
                WeeklyDistanceChart(summaries: summaries)
            }

            if summaries.filter({ $0.averagePace != nil }).count >= 2 {
                PaceTrendChart(summaries: summaries)
            }

            let zones = dataManager.heartRateZones(for: filteredSessions)
            if !zones.isEmpty {
                HRZoneChart(zones: zones)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Metric Summary

    private var metricSummary: some View {
        let totalDuration = filteredSessions.reduce(0.0) { $0 + $1.duration }
        let totalDistance = filteredSessions.compactMap(\.distance).reduce(0, +)
        let avgHR = averageHeartRate(filteredSessions)
        let totalCalories = filteredSessions.compactMap(\.caloriesBurned).reduce(0, +)

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            MetricCard(
                icon: "clock.fill",
                value: FormattingUtils.formatDuration(totalDuration),
                label: "Duration",
                color: .primary,
                compact: true
            )

            if totalDistance > 0 {
                MetricCard(
                    icon: "location.fill",
                    value: FormattingUtils.formatDistance(totalDistance),
                    label: "Distance",
                    color: ShuttlXColor.running,
                    compact: true
                )
            }

            if let hr = avgHR {
                MetricCard(
                    icon: "heart.fill",
                    value: "\(Int(hr)) BPM",
                    label: "Avg HR",
                    color: ShuttlXColor.heartRate,
                    compact: true
                )
            }

            if totalCalories > 0 {
                MetricCard(
                    icon: "flame.fill",
                    value: "\(Int(totalCalories))",
                    label: "Calories",
                    color: ShuttlXColor.calories,
                    compact: true
                )
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Session List

    private var sessionList: some View {
        LazyVStack(spacing: 0) {
            ForEach(filteredSessions) { session in
                NavigationLink(destination: SessionDetailView(session: session)) {
                    SessionRowView(session: session)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                if session.id != filteredSessions.last?.id {
                    Divider()
                        .padding(.leading)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("No training sessions")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("for this \(viewMode.rawValue.lowercased())")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No training sessions for this \(viewMode.rawValue.lowercased())")
    }

    // MARK: - Helpers

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: selectedDate)
    }

    private func changeDate(_ direction: Int) {
        let calendar = Calendar.current
        let component: Calendar.Component = viewMode == .month ? .month : (viewMode == .week ? .weekOfYear : .day)
        if let newDate = calendar.date(byAdding: component, value: direction, to: selectedDate) {
            selectedDate = newDate
        }
    }

    private func averageHeartRate(_ sessions: [TrainingSession]) -> Double? {
        let heartRates = sessions.compactMap(\.averageHeartRate)
        guard !heartRates.isEmpty else { return nil }
        return heartRates.reduce(0, +) / Double(heartRates.count)
    }
}

#Preview {
    TrainingHistoryView()
        .environmentObject(DataManager())
}
