import SwiftUI

enum HistoryViewMode: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
}

struct TrainingHistoryView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedDate = Date()
    @State private var viewMode: HistoryViewMode = .week

    var filteredSessions: [TrainingSession] {
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
        NavigationView {
            VStack {
                Picker("View Mode", selection: $viewMode) {
                    ForEach(HistoryViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .accessibilityLabel("Time period")
                .accessibilityValue(viewMode.rawValue)

                HStack {
                    Button(action: { changeDate(-1) }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                    }
                    .accessibilityLabel("Previous \(viewMode.rawValue.lowercased())")

                    Spacer()

                    Text(formattedDateRange)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("Date range: \(formattedDateRange)")

                    Spacer()

                    Button(action: { changeDate(1) }) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                    }
                    .accessibilityLabel("Next \(viewMode.rawValue.lowercased())")
                }
                .padding(.horizontal)

                if filteredSessions.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                        Text("No training sessions")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("for \(viewMode.rawValue.lowercased())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("No training sessions for this \(viewMode.rawValue.lowercased())")
                } else {
                    List {
                        // Summary section
                        Section {
                            HStack {
                                Text("Total Sessions")
                                Spacer()
                                Text("\(filteredSessions.count)")
                                    .foregroundColor(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Total Sessions: \(filteredSessions.count)")

                            HStack {
                                Text("Total Duration")
                                Spacer()
                                Text(formatTotalDuration(filteredSessions))
                                    .foregroundColor(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Total Duration: \(formatTotalDuration(filteredSessions))")

                            // Running / Walking summary
                            let totalRunning = filteredSessions.reduce(0.0) { $0 + $1.totalRunningDuration }
                            let totalWalking = filteredSessions.reduce(0.0) { $0 + $1.totalWalkingDuration }

                            if totalRunning > 0 {
                                HStack {
                                    Label("Running", systemImage: "figure.run")
                                        .foregroundColor(.green)
                                    Spacer()
                                    Text(formatTotalDurationFromSeconds(totalRunning))
                                        .foregroundColor(.secondary)
                                }
                            }

                            if totalWalking > 0 {
                                HStack {
                                    Label("Walking", systemImage: "figure.walk")
                                        .foregroundColor(.orange)
                                    Spacer()
                                    Text(formatTotalDurationFromSeconds(totalWalking))
                                        .foregroundColor(.secondary)
                                }
                            }

                            if let avgHeartRate = averageHeartRate(filteredSessions) {
                                HStack {
                                    Text("Average Heart Rate")
                                    Spacer()
                                    Text("\(Int(avgHeartRate)) BPM")
                                        .foregroundColor(.red)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Average Heart Rate: \(Int(avgHeartRate)) BPM")
                            }

                            let totalCalories = filteredSessions.compactMap { $0.caloriesBurned }.reduce(0, +)
                            if totalCalories > 0 {
                                HStack {
                                    Label("Calories", systemImage: "flame.fill")
                                        .foregroundColor(.orange)
                                    Spacer()
                                    Text("\(Int(totalCalories)) CAL")
                                        .foregroundColor(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Total Calories: \(Int(totalCalories))")
                            }

                            let totalSteps = filteredSessions.compactMap { $0.totalSteps }.reduce(0, +)
                            if totalSteps > 0 {
                                HStack {
                                    Label("Steps", systemImage: "shoeprints.fill")
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Text("\(totalSteps)")
                                        .foregroundColor(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Total Steps: \(totalSteps)")
                            }

                            let totalDist = filteredSessions.compactMap { $0.distance }.reduce(0, +)
                            if totalDist > 0 {
                                HStack {
                                    Label("Distance", systemImage: "location.fill")
                                        .foregroundColor(.green)
                                    Spacer()
                                    Text(String(format: "%.1f km", totalDist))
                                        .foregroundColor(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(String(format: "Total Distance: %.1f kilometers", totalDist))
                            }
                        }

                        Section("Training Sessions") {
                            ForEach(filteredSessions) { session in
                                NavigationLink(destination: SessionDetailView(session: session)) {
                                    SessionRowView(session: session)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Training History")
        }
    }

    private var formattedDateRange: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        switch viewMode {
        case .day:
            formatter.dateStyle = .full
            return formatter.string(from: selectedDate)
        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? selectedDate
            formatter.dateStyle = .short
            return "\(formatter.string(from: startOfWeek)) - \(formatter.string(from: endOfWeek))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: selectedDate)
        }
    }

    private func changeDate(_ direction: Int) {
        let calendar = Calendar.current
        let component: Calendar.Component

        switch viewMode {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        }

        if let newDate = calendar.date(byAdding: component, value: direction, to: selectedDate) {
            selectedDate = newDate
        }
    }

    private func formatTotalDuration(_ sessions: [TrainingSession]) -> String {
        let totalSeconds = sessions.map { $0.duration }.reduce(0, +)
        return formatTotalDurationFromSeconds(totalSeconds)
    }

    private func formatTotalDurationFromSeconds(_ totalSeconds: TimeInterval) -> String {
        let hours = Int(totalSeconds / 3600)
        let minutes = Int((totalSeconds.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func averageHeartRate(_ sessions: [TrainingSession]) -> Double? {
        let heartRates = sessions.compactMap { $0.averageHeartRate }
        guard !heartRates.isEmpty else { return nil }
        return heartRates.reduce(0, +) / Double(heartRates.count)
    }
}

#Preview {
    TrainingHistoryView()
        .environmentObject(DataManager())
}
