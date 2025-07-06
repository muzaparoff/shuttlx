import SwiftUI

struct ProgramRowView: View {
    let program: TrainingProgram
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(program.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(program.type.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            
            HStack {
                // Total duration
                Label(formatDuration(program.totalDuration), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Interval count
                Text("\(program.intervals.count) intervals")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Max pulse
                Text("Max HR: \(program.maxPulse)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Visual interval preview
            if !program.intervals.isEmpty {
                HStack(spacing: 2) {
                    ForEach(Array(program.intervals.prefix(8).enumerated()), id: \.offset) { index, interval in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(interval.phase == .work ? Color.red : Color.blue)
                            .frame(width: max(4, min(20, interval.duration / 30)), height: 4)
                    }
                    
                    if program.intervals.count > 8 {
                        Text("...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
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
    ProgramRowView(program: TrainingProgram(
        name: "Beginner Walk-Run",
        type: .walkRun,
        intervals: [
            TrainingInterval(phase: .rest, duration: 300, intensity: .low),
            TrainingInterval(phase: .work, duration: 60, intensity: .moderate),
            TrainingInterval(phase: .rest, duration: 120, intensity: .low),
            TrainingInterval(phase: .work, duration: 60, intensity: .moderate)
        ],
        maxPulse: 180,
        createdDate: Date(),
        lastModified: Date()
    ))
}
