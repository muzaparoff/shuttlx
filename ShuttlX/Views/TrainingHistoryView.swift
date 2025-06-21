import SwiftUI

struct TrainingHistoryView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        NavigationView {
            List {
                ForEach(dataManager.sessions.sorted { $0.startDate > $1.startDate }) { session in
                    SessionRowView(session: session)
                }
            }
            .navigationTitle("Training History")
        }
    }
}

struct SessionRowView: View {
    let session: TrainingSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.programName)
                    .font(.headline)
                
                Spacer()
                
                Text(formatDate(session.startDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                if let duration = session.endDate?.timeIntervalSince(session.startDate) {
                    Label(formatDuration(duration), systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let heartRate = session.averageHeartRate {
                    Label("\(Int(heartRate)) BPM", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                if let calories = session.caloriesBurned {
                    Label("\(Int(calories)) cal", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

#Preview {
    TrainingHistoryView()
        .environmentObject(DataManager())
}
