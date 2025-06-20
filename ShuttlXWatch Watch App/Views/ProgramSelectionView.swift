import SwiftUI

struct ProgramSelectionView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        NavigationView {
            Group {
                if workoutManager.availablePrograms.isEmpty {
                    EmptyProgramsWatchView()
                } else {
                    List {
                        ForEach(workoutManager.availablePrograms) { program in
                            ProgramRowWatchView(program: program) {
                                workoutManager.selectProgram(program)
                            }
                        }
                    }
                    .listStyle(.carousel)
                }
            }
            .navigationTitle("Programs")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                workoutManager.loadPrograms()
            }
        }
    }
}

struct ProgramRowWatchView: View {
    let program: TrainingProgram
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                // Program name
                Text(program.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                // Program details
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(program.intervalCount) intervals")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(program.formattedTotalDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.caption2)
                            
                            Text("\(program.maxPulse)")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        // Interval type indicators
                        HStack(spacing: 3) {
                            if program.walkIntervalCount > 0 {
                                HStack(spacing: 1) {
                                    Image(systemName: "figure.walk")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                    
                                    Text("\(program.walkIntervalCount)")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            if program.runIntervalCount > 0 {
                                HStack(spacing: 1) {
                                    Image(systemName: "figure.run")
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                    
                                    Text("\(program.runIntervalCount)")
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
                
                // Visual interval preview (simplified for watch)
                HStack(spacing: 1) {
                    ForEach(program.intervals.prefix(6)) { interval in
                        Rectangle()
                            .fill(colorForIntervalType(interval.type))
                            .frame(width: 3, height: 8)
                    }
                    
                    if program.intervals.count > 6 {
                        Text("...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private func colorForIntervalType(_ type: IntervalType) -> Color {
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

struct EmptyProgramsWatchView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No Programs")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("Create programs on your iPhone")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    ProgramSelectionView()
        .environmentObject(WatchWorkoutManager())
}
