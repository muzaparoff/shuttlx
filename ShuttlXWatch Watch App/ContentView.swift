//
//  ContentView.swift
//  ShuttlXWatch Watch App
//
//  Created by sergey on 09/06/2025.
//

import SwiftUI
import WatchConnectivity

// MARK: - Shared Training Models for watchOS

struct TrainingProgram: Identifiable, Codable {
    let id = UUID()
    var name: String
    var distance: Double // in kilometers
    var runInterval: Double // in minutes
    var walkInterval: Double // in minutes
    var totalDuration: Double // in minutes
    var difficulty: TrainingDifficulty
    var description: String
    var estimatedCalories: Int
    var targetHeartRateZone: HeartRateZone
    var createdDate: Date
    var isCustom: Bool
    
    init(
        name: String,
        distance: Double,
        runInterval: Double,
        walkInterval: Double,
        totalDuration: Double,
        difficulty: TrainingDifficulty,
        description: String = "",
        estimatedCalories: Int = 0,
        targetHeartRateZone: HeartRateZone = .moderate,
        isCustom: Bool = false
    ) {
        self.name = name
        self.distance = distance
        self.runInterval = runInterval
        self.walkInterval = walkInterval
        self.totalDuration = totalDuration
        self.difficulty = difficulty
        self.description = description
        self.estimatedCalories = estimatedCalories
        self.targetHeartRateZone = targetHeartRateZone
        self.createdDate = Date()
        self.isCustom = isCustom
    }
    
    var formattedDistance: String {
        String(format: "%.1f km", distance)
    }
    
    var formattedDuration: String {
        let hours = Int(totalDuration) / 60
        let minutes = Int(totalDuration) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
    
    var intervalPattern: String {
        "Run \(Int(runInterval))m • Walk \(Int(walkInterval))m"
    }
}

enum TrainingDifficulty: String, CaseIterable, Codable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .beginner: return "leaf.fill"
        case .intermediate: return "flame.fill"
        case .advanced: return "bolt.fill"
        }
    }
}

enum HeartRateZone: String, CaseIterable, Codable {
    case recovery = "recovery"
    case easy = "easy"
    case moderate = "moderate"
    case hard = "hard"
    case maximum = "maximum"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var color: Color {
        switch self {
        case .recovery: return .blue
        case .easy: return .green
        case .moderate: return .yellow
        case .hard: return .orange
        case .maximum: return .red
        }
    }
    
    var percentage: String {
        switch self {
        case .recovery: return "50-60%"
        case .easy: return "60-70%"
        case .moderate: return "70-80%"
        case .hard: return "80-90%"
        case .maximum: return "90-100%"
        }
    }
}

enum WorkoutPhase: String, CaseIterable {
    case warmup = "warmup"
    case running = "running"
    case walking = "walking"
    case cooldown = "cooldown"
    case rest = "rest"
    
    var displayName: String {
        switch self {
        case .warmup: return "Warm Up"
        case .running: return "Running"
        case .walking: return "Walking"
        case .cooldown: return "Cool Down"
        case .rest: return "Rest"
        }
    }
    
    var color: Color {
        switch self {
        case .warmup: return .yellow
        case .running: return .red
        case .walking: return .blue
        case .cooldown: return .purple
        case .rest: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .warmup: return "thermometer.medium"
        case .running: return "hare.fill"
        case .walking: return "tortoise.fill"
        case .cooldown: return "snowflake"
        case .rest: return "pause.circle.fill"
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @State private var trainingPrograms: [TrainingProgram] = defaultTrainingPrograms
    @State private var customPrograms: [TrainingProgram] = []
    @State private var isConnectedToPhone = false
    @StateObject private var watchConnectivity = WatchConnectivityDelegate()
    @StateObject private var coordinator = WatchConnectivityCoordinator()
    
    var allPrograms: [TrainingProgram] {
        return trainingPrograms + customPrograms
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Connection Status
                if !isConnectedToPhone {
                    HStack {
                        Image(systemName: "iphone.slash")
                            .foregroundColor(.orange)
                        Text("Phone Disconnected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
                
                // Programs List
                List {
                    if !customPrograms.isEmpty {
                        Section("Custom Programs") {
                            ForEach(customPrograms) { program in
                                NavigationLink(destination: TrainingDetailView(program: program)) {
                                    TrainingProgramRow(program: program)
                                }
                            }
                        }
                    }
                    
                    Section("Default Programs") {
                        ForEach(trainingPrograms) { program in
                            NavigationLink(destination: TrainingDetailView(program: program)) {
                                TrainingProgramRow(program: program)
                            }
                        }
                    }
                }
            }
            .navigationTitle("ShuttlX")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: requestProgramSync) {
                        Image(systemName: "arrow.clockwise.circle")
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .onAppear {
            setupWatchConnectivity()
            checkPhoneConnection()
        }
        .onReceive(coordinator.$trainingPrograms) { programs in
            if !programs.isEmpty {
                updateReceivedPrograms(programs)
            }
        }
    }
    
    private func setupWatchConnectivity() {
        watchConnectivity.delegate = coordinator
        coordinator.updatePrograms = { programs in
            DispatchQueue.main.async {
                self.updateReceivedPrograms(programs)
            }
        }
        if WCSession.isSupported() {
            WCSession.default.delegate = watchConnectivity
            WCSession.default.activate()
        }
    }
    
    private func checkPhoneConnection() {
        isConnectedToPhone = WCSession.default.isReachable
        
        // Check connection periodically
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            DispatchQueue.main.async {
                isConnectedToPhone = WCSession.default.isReachable
            }
        }
    }
    
    private func requestProgramSync() {
        guard WCSession.default.isReachable else {
            print("⌚ Phone not reachable for sync")
            return
        }
        
        let message = ["action": "sync_programs"]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("❌ Failed to request sync: \(error.localizedDescription)")
        }
    }
    
    private func updateReceivedPrograms(_ programs: [TrainingProgram]) {
        // Separate custom and default programs
        let custom = programs.filter { $0.isCustom }
        let defaults = programs.filter { !$0.isCustom }
        
        DispatchQueue.main.async {
            if !defaults.isEmpty {
                trainingPrograms = defaults
            }
            customPrograms = custom
            print("⌚ Updated programs: \(defaults.count) default, \(custom.count) custom")
        }
    }
}

// MARK: - Watch Connectivity Coordinator

class WatchConnectivityCoordinator: ObservableObject {
    @Published var trainingPrograms: [TrainingProgram] = []
    var updatePrograms: (([TrainingProgram]) -> Void)?
    
    func updateReceivedPrograms(_ programs: [TrainingProgram]) {
        updatePrograms?(programs)
    }
}

extension WatchConnectivityCoordinator: WatchConnectivityProtocol {
    func didReceiveTrainingPrograms(_ programs: [TrainingProgram]) {
        DispatchQueue.main.async {
            self.trainingPrograms = programs
            self.updatePrograms?(programs)
        }
    }
    
    func didReceiveSelectedProgram(_ program: TrainingProgram) {
        // Handle selected program from phone
        print("⌚ Received selected program: \(program.name)")
    }
}

// MARK: - Watch Connectivity Protocol

protocol WatchConnectivityProtocol: AnyObject {
    func didReceiveTrainingPrograms(_ programs: [TrainingProgram])
    func didReceiveSelectedProgram(_ program: TrainingProgram)
}

class WatchConnectivityDelegate: NSObject, ObservableObject, WCSessionDelegate {
    weak var delegate: WatchConnectivityProtocol?
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            print("⌚ Watch session activated with state: \(activationState.rawValue)")
            if let error = error {
                print("❌ Watch session activation error: \(error.localizedDescription)")
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            self.handleReceivedMessage(message)
            replyHandler(["status": "received"])
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.handleReceivedMessage(message)
        }
    }
    
    private func handleReceivedMessage(_ message: [String: Any]) {
        if let data = message["training_programs"] as? Data {
            handleTrainingPrograms(data)
        }
        
        if let data = message["selected_program"] as? Data {
            handleSelectedProgram(data)
        }
    }
    
    private func handleTrainingPrograms(_ data: Data) {
        do {
            let decoder = JSONDecoder()
            let programs = try decoder.decode([TrainingProgram].self, from: data)
            delegate?.didReceiveTrainingPrograms(programs)
            print("⌚ Received \(programs.count) training programs from iPhone")
        } catch {
            print("❌ Failed to decode training programs: \(error.localizedDescription)")
        }
    }
    
    private func handleSelectedProgram(_ data: Data) {
        do {
            let decoder = JSONDecoder()
            let program = try decoder.decode(TrainingProgram.self, from: data)
            delegate?.didReceiveSelectedProgram(program)
            print("⌚ Received selected program: \(program.name)")
        } catch {
            print("❌ Failed to decode selected program: \(error.localizedDescription)")
        }
    }
}

// MARK: - Default Training Programs

let defaultTrainingPrograms: [TrainingProgram] = [
    TrainingProgram(
        name: "Beginner 5K",
        distance: 5.0,
        runInterval: 1.0,
        walkInterval: 2.0,
        totalDuration: 35.0,
        difficulty: .beginner,
        description: "Perfect for beginners starting their running journey",
        estimatedCalories: 250,
        targetHeartRateZone: .easy
    ),
    
    TrainingProgram(
        name: "HIIT Blast",
        distance: 3.0,
        runInterval: 1.5,
        walkInterval: 1.0,
        totalDuration: 25.0,
        difficulty: .advanced,
        description: "High-intensity intervals for maximum calorie burn",
        estimatedCalories: 300,
        targetHeartRateZone: .hard
    ),
    
    TrainingProgram(
        name: "Endurance Challenge",
        distance: 8.0,
        runInterval: 3.0,
        walkInterval: 1.0,
        totalDuration: 50.0,
        difficulty: .intermediate,
        description: "Build your endurance with longer running intervals",
        estimatedCalories: 480,
        targetHeartRateZone: .moderate
    ),
    
    TrainingProgram(
        name: "Speed Demon",
        distance: 4.0,
        runInterval: 0.5,
        walkInterval: 0.5,
        totalDuration: 20.0,
        difficulty: .advanced,
        description: "Short bursts of maximum effort for speed training",
        estimatedCalories: 320,
        targetHeartRateZone: .maximum
    ),
    
    TrainingProgram(
        name: "Recovery Run",
        distance: 3.0,
        runInterval: 2.0,
        walkInterval: 3.0,
        totalDuration: 30.0,
        difficulty: .beginner,
        description: "Gentle intervals for active recovery days",
        estimatedCalories: 180,
        targetHeartRateZone: .recovery
    ),
    
    TrainingProgram(
        name: "Marathon Prep",
        distance: 10.0,
        runInterval: 4.0,
        walkInterval: 1.0,
        totalDuration: 60.0,
        difficulty: .advanced,
        description: "Long-distance training for marathon preparation",
        estimatedCalories: 600,
        targetHeartRateZone: .moderate
    )
]

struct DifficultyBadge: View {
    let difficulty: TrainingDifficulty
    
    var body: some View {
        Text(difficulty.rawValue.capitalized)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(difficulty.color.opacity(0.2))
            .foregroundColor(difficulty.color)
            .clipShape(Capsule())
    }
}

// MARK: - TrainingProgramRow

struct TrainingProgramRow: View {
    let program: TrainingProgram
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(program.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: program.difficulty.icon)
                    .foregroundColor(program.difficulty.color)
            }
            
            Text(program.intervalPattern)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text(program.formattedDistance)
                    .font(.caption2)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Text(program.formattedDuration)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - TrainingDetailView

struct TrainingDetailView: View {
    let program: TrainingProgram
    @State private var isWorkoutActive = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Program Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(program.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    DifficultyBadge(difficulty: program.difficulty)
                }
                
                // Program Stats
                VStack(spacing: 12) {
                    StatsRow(icon: "location", label: "Distance", value: "\(String(format: "%.1f", program.distance)) km")
                    StatsRow(icon: "clock", label: "Duration", value: "\(Int(program.totalDuration)) min")
                    StatsRow(icon: "figure.run", label: "Run Interval", value: "\(Int(program.runInterval)) min")
                    StatsRow(icon: "figure.walk", label: "Walk Interval", value: "\(Int(program.walkInterval)) min")
                }
                
                // Start Workout Button
                Button(action: {
                    isWorkoutActive = true
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Workout")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
        }
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isWorkoutActive) {
            WorkoutView(program: program)
        }
    }
}

struct StatsRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 20)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct WorkoutView: View {
    let program: TrainingProgram
    @Environment(\.dismiss) private var dismiss
    @State private var currentPhase: WorkoutPhase = .running
    @State private var timeRemaining: TimeInterval = 180 // 3 minutes
    @State private var isActive = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Program Name
            Text(program.name)
                .font(.headline)
                .foregroundColor(.orange)
            
            // Current Phase
            VStack(spacing: 8) {
                Text(currentPhase.rawValue.uppercased())
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(currentPhase.color)
                
                Text(formatTime(timeRemaining))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            // Controls
            HStack(spacing: 20) {
                Button(action: {
                    isActive.toggle()
                }) {
                    Image(systemName: isActive ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.orange)
                        .clipShape(Circle())
                }
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .navigationBarHidden(true)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    ContentView()
}
