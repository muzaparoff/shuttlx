import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        TabView {
            ProgramListView()
                .tabItem {
                    Label("Programs", systemImage: "list.bullet")
                }
            
            TrainingHistoryView()
                .tabItem {
                    Label("History", systemImage: "calendar")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager())
}
    let id: UUID
    var name: String
    var type: ProgramType
    var intervals: [TrainingInterval]
    var maxPulse: Int
    var createdDate: Date
    var lastModified: Date
    
    init(name: String, type: ProgramType, intervals: [TrainingInterval], maxPulse: Int, createdDate: Date = Date(), lastModified: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.intervals = intervals
        self.maxPulse = maxPulse
        self.createdDate = createdDate
        self.lastModified = lastModified
    }
    
    // Computed properties
    var totalDuration: TimeInterval {
        intervals.reduce(0) { $0 + $1.duration }
    }
    
    var workIntervals: [TrainingInterval] {
        intervals.filter { $0.phase == .work }
    }
    
    var restIntervals: [TrainingInterval] {
        intervals.filter { $0.phase == .rest }
    }
}

enum ProgramType: String, CaseIterable, Codable {
    case walkRun = "Walk-Run"
    case hiit = "HIIT"
    case tabata = "Tabata"
    case custom = "Custom"
    
    var description: String {
        switch self {
        case .walkRun: 
            return "Alternating walking and running intervals for endurance building"
        case .hiit: 
            return "High-Intensity Interval Training for maximum calorie burn"
        case .tabata: 
            return "20 seconds work, 10 seconds rest protocol"
        case .custom: 
            return "Fully customizable interval training"
        }
    }
    
    var defaultIntervals: [TrainingInterval] {
        switch self {
        case .walkRun:
            return [
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate),
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate)
            ]
        case .hiit, .tabata, .custom:
            return []
        }
    }
    
    var workPhaseLabel: String {
        switch self {
        case .walkRun: return "Run"
        case .hiit: return "High Intensity"
        case .tabata: return "Work"
        case .custom: return "Work"
        }
    }
    
    var restPhaseLabel: String {
        switch self {
        case .walkRun: return "Walk"
        case .hiit: return "Rest"
        case .tabata: return "Rest"
        case .custom: return "Rest"
        }
    }
}

struct TrainingInterval: Identifiable, Codable {
    let id: UUID
    var phase: IntervalPhase
    var duration: TimeInterval // in seconds
    var intensity: TrainingIntensity
    
    init(phase: IntervalPhase, duration: TimeInterval, intensity: TrainingIntensity) {
        self.id = UUID()
        self.phase = phase
        self.duration = duration
        self.intensity = intensity
    }
}

enum IntervalPhase: String, CaseIterable, Codable {
    case work = "Work"
    case rest = "Rest"
    
    var displayName: String {
        switch self {
        case .work: return "Work"
        case .rest: return "Rest"
        }
    }
    
    var systemImage: String {
        switch self {
        case .work: return "bolt.fill"
        case .rest: return "pause.circle.fill"
        }
    }
}

enum TrainingIntensity: String, CaseIterable, Codable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    
    var description: String {
        switch self {
        case .low: return "Easy pace, conversational"
        case .moderate: return "Moderate effort, slightly breathless"
        case .high: return "High intensity, maximum effort"
        }
    }
}

struct TrainingSession: Identifiable, Codable {
    let id: UUID
    var programID: UUID
    var programName: String
    var startDate: Date
    var endDate: Date?
    var duration: TimeInterval
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var caloriesBurned: Double?
    var distance: Double?
    var completedIntervals: [CompletedInterval]
    
    init(programID: UUID, programName: String, startDate: Date, endDate: Date? = nil, duration: TimeInterval, averageHeartRate: Double? = nil, maxHeartRate: Double? = nil, caloriesBurned: Double? = nil, distance: Double? = nil, completedIntervals: [CompletedInterval] = []) {
        self.id = UUID()
        self.programID = programID
        self.programName = programName
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.caloriesBurned = caloriesBurned
        self.distance = distance
        self.completedIntervals = completedIntervals
    }
}

struct CompletedInterval: Identifiable, Codable {
    let id: UUID
    var intervalID: UUID
    var actualDuration: TimeInterval
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    
    init(intervalID: UUID, actualDuration: TimeInterval, averageHeartRate: Double? = nil, maxHeartRate: Double? = nil) {
        self.id = UUID()
        self.intervalID = intervalID
        self.actualDuration = actualDuration
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
    }
}

// MARK: - DataManager
class DataManager: ObservableObject {
    @Published var programs: [TrainingProgram] = []
    @Published var sessions: [TrainingSession] = []
    
    init() {
        loadSampleData()
    }
    
    private func loadSampleData() {
        let sampleProgram = TrainingProgram(
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
        )
        
        programs = [sampleProgram]
    }
    
    func saveProgram(_ program: TrainingProgram) {
        if let index = programs.firstIndex(where: { $0.id == program.id }) {
            programs[index] = program
        } else {
            programs.append(program)
        }
    }
    
    func deleteProgram(_ program: TrainingProgram) {
        programs.removeAll { $0.id == program.id }
    }
    
    func saveSession(_ session: TrainingSession) {
        sessions.append(session)
    }
}

// MARK: - Views
struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        TabView {
            ProgramListView()
                .tabItem {
                    Label("Programs", systemImage: "list.bullet")
                }
            
            TrainingHistoryView()
                .tabItem {
                    Label("History", systemImage: "calendar")
                }
        }
    }
}

struct ProgramListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingEditor = false
    @State private var selectedProgram: TrainingProgram?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(dataManager.programs) { program in
                    VStack(alignment: .leading) {
                        Text(program.name)
                            .font(.headline)
                        Text("\(program.intervals.count) intervals")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .onTapGesture {
                        selectedProgram = program
                        showingEditor = true
                    }
                }
                .onDelete(perform: deletePrograms)
            }
            .navigationTitle("Training Programs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        selectedProgram = nil
                        showingEditor = true
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                ProgramEditorView(program: selectedProgram)
            }
        }
    }
    
    private func deletePrograms(offsets: IndexSet) {
        for index in offsets {
            dataManager.deleteProgram(dataManager.programs[index])
        }
    }
}

struct ProgramEditorView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var program: TrainingProgram
    
    init(program: TrainingProgram?) {
        if let existingProgram = program {
            _program = State(initialValue: existingProgram)
        } else {
            _program = State(initialValue: TrainingProgram(
                name: "",
                type: .walkRun,
                intervals: [],
                maxPulse: 180,
                createdDate: Date(),
                lastModified: Date()
            ))
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Program Details") {
                    TextField("Program Name", text: $program.name)
                    
                    Picker("Training Type", selection: $program.type) {
                        ForEach(ProgramType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    Stepper("Max Pulse: \(program.maxPulse)", value: $program.maxPulse, in: 100...220)
                }
                
                Section("Intervals") {
                    ForEach(Array(program.intervals.enumerated()), id: \.offset) { index, interval in
                        HStack {
                            Circle()
                                .fill(interval.phase == .work ? Color.red : Color.blue)
                                .frame(width: 12, height: 12)
                            
                            VStack(alignment: .leading) {
                                Text(interval.phase == .work ? program.type.workPhaseLabel : program.type.restPhaseLabel)
                                    .font(.headline)
                                Text("\(interval.intensity.rawValue) • \(formatDuration(interval.duration))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: interval.phase.systemImage)
                                .foregroundColor(interval.phase == .work ? .red : .blue)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteInterval)
                    
                    // Quick Add Buttons
                    HStack(spacing: 12) {
                        Button(action: addWorkInterval) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text(program.type.workPhaseLabel)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundColor(.white)
                            .background(Color.red)
                            .cornerRadius(8)
                        }
                        
                        Button(action: addRestInterval) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text(program.type.restPhaseLabel)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .navigationTitle(program.name.isEmpty ? "New Program" : program.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProgram()
                    }
                    .disabled(program.name.isEmpty)
                }
            }
        }
    }
    
    private func addWorkInterval() {
        let interval = TrainingInterval(phase: .work, duration: 60, intensity: .moderate)
        program.intervals.append(interval)
    }
    
    private func addRestInterval() {
        let interval = TrainingInterval(phase: .rest, duration: 60, intensity: .low)
        program.intervals.append(interval)
    }
    
    private func deleteInterval(offsets: IndexSet) {
        program.intervals.remove(atOffsets: offsets)
    }
    
    private func saveProgram() {
        program.lastModified = Date()
        dataManager.saveProgram(program)
        presentationMode.wrappedValue.dismiss()
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

struct TrainingHistoryView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        NavigationView {
            List {
                ForEach(dataManager.sessions.sorted { $0.startDate > $1.startDate }) { session in
                    VStack(alignment: .leading) {
                        Text(session.programName)
                            .font(.headline)
                        Text(formatDate(session.startDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Training History")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}