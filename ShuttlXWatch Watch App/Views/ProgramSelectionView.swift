import SwiftUI

struct ProgramSelectionView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var showingDebugView = false
    
    var body: some View {
        List {
            Button(action: {
                showingDebugView = true
            }) {
                Text("Debug Info")
            }
            .sheet(isPresented: $showingDebugView) {
                DebugView()
            }

            ForEach(workoutManager.availablePrograms, id: \.id) { program in
                Button(action: {
                    workoutManager.startWorkout(with: program)
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(program.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Text("\(program.intervals.count) intervals")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(formatDuration(program.totalDuration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Visual preview of intervals
                        HStack(spacing: 2) {
                            ForEach(Array(program.intervals.enumerated()), id: \.offset) { index, interval in
                                Rectangle()
                                    .fill(interval.phase == .work ? Color.red : Color.blue)
                                    .frame(height: 4)
                                    .frame(width: max(2, min(8, interval.duration / 30)))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .navigationTitle("Programs")
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return remainingSeconds > 0 ? "\(minutes)m \(remainingSeconds)s" : "\(minutes)m"
        } else {
            return "\(remainingSeconds)s"
        }
    }
}

#Preview {
    NavigationView {
        ProgramSelectionView()
            .environmentObject(WatchWorkoutManager())
    }
}
