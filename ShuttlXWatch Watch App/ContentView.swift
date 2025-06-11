//
//  ContentView.swift
//  ShuttlXWatch Watch App
//
//  Created by sergey on 09/06/2025.
//

import SwiftUI
import WatchConnectivity
import HealthKit

// MARK: - Enums (defined first to avoid forward reference issues)

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

// MARK: - Default Training Programs (defined before ContentView)

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

// MARK: - ContentView

struct ContentView: View {
    @State private var trainingPrograms: [TrainingProgram] = defaultTrainingPrograms
    @State private var customPrograms: [TrainingProgram] = []
    @State private var isConnectedToPhone = false
    @StateObject private var watchConnectivity = WatchConnectivityDelegate()
    @StateObject private var coordinator = WatchConnectivityCoordinator()
    @EnvironmentObject var workoutManager: WatchWorkoutManager // Add environment object reference
    @Environment(\.dismiss) var dismiss
    
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Test") {
                        // Test button for debugging - functionality can be added here
                    }
                    .foregroundColor(.green)
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
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
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
                
                // TIMER DEBUG TEST BUTTON
                Button(action: {
                    print("🧪 [DEBUG-UI] Quick Timer Test button pressed")
                    workoutManager.startQuickTest()
                    isWorkoutActive = true
                    print("🧪 [DEBUG-UI] Quick test started - showing WorkoutView")
                }) {
                    HStack {
                        Image(systemName: "timer")
                        Text("Quick Timer Test")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Start Workout Button
                Button(action: {
                    print("🔴 [UI-DEBUG] Start Workout button pressed for program: \(program.name)")
                    print("🔴 [UI-DEBUG] WorkoutManager state before start: isActive=\(workoutManager.isWorkoutActive)")
                    
                    // Start the workout immediately so timer activates right away
                    workoutManager.startWorkout(from: program)
                    
                    print("🔴 [UI-DEBUG] WorkoutManager.startWorkout() called")
                    print("🔴 [UI-DEBUG] WorkoutManager state after start: isActive=\(workoutManager.isWorkoutActive)")
                    print("🔴 [UI-DEBUG] Current intervals count: \(workoutManager.intervals.count)")
                    print("🔴 [UI-DEBUG] Current interval: \(workoutManager.currentInterval?.name ?? "nil")")
                    
                    isWorkoutActive = true
                    print("🔴 [UI-DEBUG] Setting isWorkoutActive to true - should show WorkoutView")
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
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var currentTab = 0
    
    var body: some View {
        TabView(selection: $currentTab) {
            // Main Timer Display
            MainTimerView(program: program)
                .tag(0)
            
            // Metrics View
            WorkoutMetricsView(program: program)
                .tag(1)
            
            // Controls
            WorkoutControlsView(program: program)
                .tag(2)
        }
        .tabViewStyle(PageTabViewStyle())
        .navigationBarHidden(true)
        .onAppear {
            // Workout already started when button was pressed - no need to start again
            print("📱 [DEBUG] WorkoutView appeared, workout should already be active: \(workoutManager.isWorkoutActive)")
            print("📱 [DEBUG] Current intervals: \(workoutManager.intervals.count)")
            print("📱 [DEBUG] Current interval index: \(workoutManager.currentIntervalIndex)")
            print("📱 [DEBUG] Current interval: \(workoutManager.currentInterval?.name ?? "nil")")
            print("📱 [DEBUG] Remaining time: \(workoutManager.remainingIntervalTime)")
            print("📱 [DEBUG] Elapsed time: \(workoutManager.elapsedTime)")
        }
        .onDisappear {
            // Keep workout running when view disappears - workout continues in background
        }
    }
}

// MARK: - Main Timer View
struct MainTimerView: View {
    let program: TrainingProgram
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            // Debug info at the top - remove this after debugging
            if workoutManager.isWorkoutActive {
                VStack {
                    Text("DEBUG: Active=\(workoutManager.isWorkoutActive ? "YES" : "NO")")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("Interval: \(workoutManager.currentInterval?.name ?? "NIL")")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("Remaining: \(Int(workoutManager.remainingIntervalTime))s")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("Elapsed: \(Int(workoutManager.elapsedTime))s")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("Formatted: \(formattedRemainingTime)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("Manager Formatted: \(workoutManager.formattedRemainingTime)")
                        .font(.caption2)
                        .foregroundColor(.purple)
                }
                .padding(4)
                .background(Color.green.opacity(0.2))
                .cornerRadius(4)
            } else {
                VStack {
                    Text("DEBUG: WORKOUT NOT ACTIVE")
                        .font(.caption2)
                        .foregroundColor(.red)
                    Text("Remaining: \(Int(workoutManager.remainingIntervalTime))s")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
                .padding(4)
                .background(Color.red.opacity(0.2))
                .cornerRadius(4)
            }
            
            // Current Activity Header
            currentActivityHeader
            
            // Main Timer Circle
            mainTimerCircle
            
            // Current Interval Progress
            intervalProgress
            
            // Quick Actions
            quickActions
        }
        .padding()
        .background(backgroundColor)
    }
    
    // MARK: - Current Activity Header
    private var currentActivityHeader: some View {
        VStack(spacing: 4) {
            HStack {
                Circle()
                    .fill(currentActivityColor)
                    .frame(width: 12, height: 12)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: workoutManager.isWorkoutActive)
                
                Text(currentActivityText)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Text("Interval \(workoutManager.currentIntervalIndex + 1) of \(workoutManager.intervals.count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Main Timer Circle
    private var mainTimerCircle: some View {
        ZStack {
            // Background Circle
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                .frame(width: 120, height: 120)
            
            // Progress Circle
            Circle()
                .trim(from: 0, to: intervalProgressValue)
                .stroke(currentActivityColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: intervalProgressValue)
            
            // Timer Text
            VStack(spacing: 4) {
                Text(formattedRemainingTime)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .monospacedDigit()
                
                Text("remaining")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Interval Progress
    private var intervalProgress: some View {
        VStack(spacing: 8) {
            // Total Program Progress
            VStack(spacing: 4) {
                HStack {
                    Text("Program Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formattedTotalRemainingTime)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
                
                ProgressView(value: totalProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                    .scaleEffect(y: 1.5)
            }
            
            // Next Activity Preview
            if let nextInterval = workoutManager.nextInterval {
                HStack {
                    Text("Next:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: nextInterval.type.icon)
                            .foregroundColor(nextInterval.type.color)
                        Text(nextInterval.name)
                            .fontWeight(.medium)
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Quick Actions
    private var quickActions: some View {
        HStack(spacing: 20) {
            // Pause/Resume Button
            Button(action: {
                if workoutManager.isWorkoutPaused {
                    workoutManager.resumeWorkout()
                } else {
                    workoutManager.pauseWorkout()
                }
            }) {
                Image(systemName: workoutManager.isWorkoutPaused ? "play.fill" : "pause.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(workoutManager.isWorkoutPaused ? .green : .orange)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Skip Interval Button
            Button(action: {
                workoutManager.skipToNextInterval()
            }) {
                Image(systemName: "forward.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(.blue)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // End Workout Button
            Button(action: {
                workoutManager.endWorkout()
                dismiss()
            }) {
                Image(systemName: "stop.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(.red)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Computed Properties
    
    private var currentActivityText: String {
        guard let currentInterval = workoutManager.currentInterval else {
            // If no current interval, show the first interval name if available
            if let firstInterval = workoutManager.intervals.first {
                return firstInterval.name
            }
            return "Ready"
        }
        
        switch currentInterval.type {
        case .warmup:
            return "Warming Up"
        case .work:
            return "Running 🏃‍♂️"
        case .rest:
            return "Walking 🚶‍♂️"
        case .cooldown:
            return "Cooling Down"
        }
    }
    
    private var currentActivityColor: Color {
        guard let currentInterval = workoutManager.currentInterval else {
            return .gray
        }
        
        switch currentInterval.type {
        case .warmup:
            return .yellow
        case .work:
            return .red
        case .rest:
            return .blue
        case .cooldown:
            return .green
        }
    }
    
    private var backgroundColor: LinearGradient {
        LinearGradient(
            colors: [
                currentActivityColor.opacity(0.1),
                Color.black.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var intervalProgressValue: CGFloat {
        guard let currentInterval = workoutManager.currentInterval,
              currentInterval.duration > 0 else {
            return 0
        }
        
        let elapsed = currentInterval.duration - workoutManager.remainingIntervalTime
        return CGFloat(elapsed / currentInterval.duration)
    }
    
    private var totalProgress: Double {
        let totalDuration = program.totalDuration * 60 // Convert to seconds
        let elapsed = workoutManager.elapsedTime
        return min(elapsed / totalDuration, 1.0)
    }
    
    private var formattedRemainingTime: String {
        let remaining = workoutManager.remainingIntervalTime
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var formattedTotalRemainingTime: String {
        let totalDuration = program.totalDuration * 60 // Convert to seconds
        let remaining = totalDuration - workoutManager.elapsedTime
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        
        if remaining > 3600 { // More than an hour
            let hours = Int(remaining) / 3600
            let mins = (Int(remaining) % 3600) / 60
            return String(format: "%d:%02d:%02d", hours, mins, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

struct WorkoutMetricsView: View {
    let program: TrainingProgram
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        VStack(spacing: 8) {
            // Program Name
            Text(program.name)
                .font(.headline)
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)
            
            // Timer
            VStack {
                Text(workoutManager.formattedElapsedTime)
                    .font(.title)
                    .foregroundColor(.primary)
                Text("ELAPSED TIME")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Main metrics
            HStack {
                MetricView(
                    value: "\(Int(workoutManager.heartRate))",
                    unit: "BPM",
                    label: "HEART RATE",
                    color: .red
                )
                
                MetricView(
                    value: "\(Int(workoutManager.activeCalories))",
                    unit: "CAL",
                    label: "CALORIES",
                    color: .orange
                )
            }
            
            // Distance (if available)
            if workoutManager.distance > 0 {
                MetricView(
                    value: String(format: "%.2f", workoutManager.distance),
                    unit: "KM",
                    label: "DISTANCE",
                    color: .green
                )
            }
            
            // Current interval info
            if let currentInterval = workoutManager.currentInterval {
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: currentInterval.type.icon)
                            .foregroundColor(currentInterval.type.color)
                        Text(currentInterval.type.displayName)
                            .font(.headline)
                            .foregroundColor(currentInterval.type.color)
                    }
                    
                    HStack {
                        Text("Interval \(workoutManager.currentIntervalIndex + 1) of \(workoutManager.totalIntervals)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(workoutManager.formattedIntervalTime)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    ProgressView(value: workoutManager.intervalProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: currentInterval.type.color))
                }
                .padding(.top, 8)
            }
        }
        .padding()
    }
}

struct MetricView: View {
    let value: String
    let unit: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct WorkoutControlsView: View {
    let program: TrainingProgram
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            // Program info
            Text(program.name)
                .font(.headline)
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)
            
            // Primary control button
            Button(action: {
                if workoutManager.isWorkoutActive {
                    if workoutManager.isWorkoutPaused {
                        workoutManager.resumeWorkout()
                    } else {
                        workoutManager.pauseWorkout()
                    }
                }
            }) {
                HStack {
                    Image(systemName: workoutManager.isWorkoutPaused ? "play.fill" : "pause.fill")
                    Text(workoutManager.isWorkoutPaused ? "Resume" : "Pause")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(workoutManager.isWorkoutPaused ? .green : .orange)
                .cornerRadius(25)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!workoutManager.isWorkoutActive)
            
            // Secondary controls
            if workoutManager.isWorkoutActive {
                HStack(spacing: 12) {
                    // Skip interval
                    Button(action: {
                        workoutManager.skipToNextInterval()
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: "forward.fill")
                                .font(.title3)
                            Text("Skip")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                        .frame(width: 60, height: 50)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // End workout
                    Button(action: {
                        workoutManager.endWorkout()
                        dismiss()
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: "stop.fill")
                                .font(.title3)
                            Text("End")
                                .font(.caption2)
                        }
                        .foregroundColor(.red)
                        .frame(width: 60, height: 50)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Workout completion handling
            if workoutManager.workoutPhase == .completed {
                VStack(spacing: 12) {
                    Text("Workout Complete!")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Done")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(25)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
    }
}

struct WorkoutProgressView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Overall progress
            VStack(spacing: 8) {
                Text("Workout Progress")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                CircularProgressView(
                    progress: workoutManager.overallProgress,
                    color: .blue
                )
                .frame(width: 80, height: 80)
                
                Text("\(Int(workoutManager.overallProgress * 100))% Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Interval breakdown
            if workoutManager.totalIntervals > 0 {
                VStack(spacing: 8) {
                    Text("Intervals")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("Completed")
                        Spacer()
                        Text("\(workoutManager.currentIntervalIndex) / \(workoutManager.totalIntervals)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    // Progress bar
                    ProgressView(value: Double(workoutManager.currentIntervalIndex) / Double(workoutManager.totalIntervals))
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                }
            }
            
            // Performance metrics
            VStack(spacing: 6) {
                Text("Performance")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                HStack {
                    Text("Avg HR")
                    Spacer()
                    Text("\(Int(workoutManager.averageHeartRate)) BPM")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                HStack {
                    Text("Max HR")
                    Spacer()
                    Text("\(Int(workoutManager.maxHeartRate)) BPM")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                if workoutManager.distance > 0 {
                    HStack {
                        Text("Pace")
                        Spacer()
                        Text(workoutManager.formattedPace)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 8)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

#Preview {
    ContentView()
}
