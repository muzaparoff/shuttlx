import SwiftUI

struct TrainingHistoryView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedSession: TrainingSession?
    @State private var showingSessionDetail = false
    
    var body: some View {
        NavigationView {
            Group {
                if dataManager.sessions.isEmpty {
                    EmptyHistoryView()
                } else {
                    List {
                        ForEach(groupedSessions, id: \.key) { month, sessions in
                            Section(month) {
                                ForEach(sessions) { session in
                                    SessionRowView(session: session)
                                        .onTapGesture {
                                            selectedSession = session
                                            showingSessionDetail = true
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Training History")
            .refreshable {
                dataManager.loadFromCloudKit()
            }
            .sheet(isPresented: $showingSessionDetail) {
                if let session = selectedSession {
                    SessionDetailView(session: session)
                }
            }
        }
    }
    
    private var groupedSessions: [(key: String, value: [TrainingSession])] {
        let sorted = dataManager.sessions.sorted { $0.startDate > $1.startDate }
        let grouped = Dictionary(grouping: sorted) { session in
            DateFormatter.monthYear.string(from: session.startDate)
        }
        return grouped.sorted { $0.key > $1.key }
    }
}

struct SessionRowView: View {
    let session: TrainingSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.programName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(session.formattedStartDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                // Duration
                Label(session.formattedDuration, systemImage: "timer")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Heart rate if available
                if let avgHR = session.averageHeartRate {
                    Label("\(Int(avgHR)) bpm", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                // Calories if available
                if let calories = session.caloriesBurned {
                    Label("\(Int(calories)) cal", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            // Completion indicator
            HStack {
                if session.isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text("Completed")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "pause.circle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        
                        Text("Incomplete")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                Text("\(session.completedIntervals.count) intervals")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct SessionDetailView: View {
    let session: TrainingSession
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.programName)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(session.formattedStartDate)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Summary metrics
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        MetricCard(
                            title: "Duration",
                            value: session.formattedDuration,
                            icon: "timer",
                            color: .blue
                        )
                        
                        MetricCard(
                            title: "Heart Rate",
                            value: session.formattedAverageHeartRate,
                            icon: "heart.fill",
                            color: .red
                        )
                        
                        MetricCard(
                            title: "Calories",
                            value: session.formattedCalories,
                            icon: "flame.fill",
                            color: .orange
                        )
                        
                        MetricCard(
                            title: "Distance",
                            value: session.formattedDistance,
                            icon: "figure.run",
                            color: .green
                        )
                    }
                    
                    // Interval breakdown
                    if !session.completedIntervals.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Interval Breakdown")
                                .font(.headline)
                            
                            ForEach(session.completedIntervals.indices, id: \.self) { index in
                                CompletedIntervalRow(
                                    interval: session.completedIntervals[index],
                                    intervalNumber: index + 1
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Session Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CompletedIntervalRow: View {
    let interval: CompletedInterval
    let intervalNumber: Int
    
    var body: some View {
        HStack {
            // Interval info
            HStack(spacing: 8) {
                Text("\(intervalNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                Image(systemName: interval.intervalType.systemImageName)
                    .foregroundColor(colorForType(interval.intervalType))
                    .frame(width: 20)
                
                Text(interval.intervalType.rawValue)
                    .font(.body)
            }
            
            Spacer()
            
            // Duration comparison
            VStack(alignment: .trailing, spacing: 2) {
                Text(interval.formattedActualDuration)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text("target: \(interval.formattedPlannedDuration)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Heart rate if available
            if let avgHR = interval.averageHeartRate {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(avgHR))")
                        .font(.body)
                        .foregroundColor(.red)
                    
                    Text("bpm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 50)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private func colorForType(_ type: IntervalType) -> Color {
        switch type {
        case .walk:
            return .blue
        case .run:
            return .red
        case .rest:
            return .gray
        }
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Training History")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Complete your first training session to see your history here")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
}

extension TrainingSession {
    var formattedStartDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }
}

#Preview {
    NavigationView {
        TrainingHistoryView()
    }
    .environmentObject(DataManager())
}
