//
//  ContentView.swift
//  ShuttlXWatch Watch App
//
//  Created by sergey on 09/06/2025.
//

import SwiftUI
import WatchConnectivity
import HealthKit
import SharedModels

// MARK: - ContentView

struct ContentView: View {
    @State private var trainingPrograms: [TrainingProgram] = TrainingProgram.defaultPrograms
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
            List {
                // Custom Workouts Section
                if !customPrograms.isEmpty {
                    Section("My Workouts") {
                        ForEach(customPrograms) { program in
                            NavigationLink(destination: TrainingDetailView(program: program)) {
                                SimpleWorkoutRow(program: program, isCustom: true)
                            }
                        }
                        .onDelete(perform: deleteCustomPrograms)
                    }
                } else {
                    Section("My Workouts") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No custom workouts")
                                .foregroundColor(.secondary)
                                .font(.body)
                            
                            Text("Create on iPhone → Auto-sync here")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Training Programs Section
                Section("Programs") {
                    ForEach(trainingPrograms) { program in
                        NavigationLink(destination: TrainingDetailView(program: program)) {
                            SimpleWorkoutRow(program: program, isCustom: false)
                        }
                    }
                }
            }
            .navigationTitle("ShuttlX")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: requestProgramSync) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .onAppear {
            setupWatchConnectivity()
            checkPhoneConnection()
            loadCustomWorkouts()
        }
        .onReceive(coordinator.$trainingPrograms) { programs in
            if !programs.isEmpty {
                updateReceivedPrograms(programs)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TrainingProgramsUpdated"))) { notification in
            if let programs = notification.object as? [TrainingProgram] {
                updateReceivedPrograms(programs)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CustomWorkoutAdded"))) { notification in
            if let workout = notification.object as? TrainingProgram {
                DispatchQueue.main.async {
                    if !self.customPrograms.contains(where: { $0.id == workout.id }) {
                        self.customPrograms.append(workout)
                        self.saveCustomWorkouts()
                        print("⌚ ✅ Custom workout added via notification: \(workout.name)")
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AllCustomWorkoutsSynced"))) { notification in
            if let workouts = notification.object as? [TrainingProgram] {
                DispatchQueue.main.async {
                    self.customPrograms = workouts
                    self.saveCustomWorkouts()
                    print("⌚ ✅ Updated custom programs from sync: \(workouts.count)")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CustomWorkoutUpdated"))) { notification in
            if let workout = notification.object as? TrainingProgram {
                DispatchQueue.main.async {
                    if let index = self.customPrograms.firstIndex(where: { $0.id == workout.id }) {
                        self.customPrograms[index] = workout
                        self.saveCustomWorkouts()
                        print("⌚ ✅ Custom workout updated via notification: \(workout.name)")
                    }
                }
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
        // Use a more reliable connection check for watchOS
        let session = WCSession.default
        let isSessionActivated = session.activationState == .activated
        let isReachable = session.isReachable
        
        // Connection is considered good if session is activated
        // Even if not immediately reachable, the connection infrastructure is there
        isConnectedToPhone = isSessionActivated
        
        print("⌚ Connection Status: Activated=\(isSessionActivated), Reachable=\(isReachable)")
        
        // Check connection less frequently and with better logic
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            DispatchQueue.main.async {
                let session = WCSession.default
                // Show as connected if session is activated, regardless of immediate reachability
                self.isConnectedToPhone = session.activationState == .activated
                
                // Only show disconnected if there's a real problem
                if !self.isConnectedToPhone {
                    print("⌚ Connection issue detected - State: \(session.activationState.rawValue)")
                }
            }
        }
    }
    
    private func requestProgramSync() {
        print("⌚ [CUSTOM-WORKOUT-SYNC-FIX] requestProgramSync() called")
        
        guard WCSession.default.isReachable else {
            print("⌚ [CUSTOM-WORKOUT-SYNC-FIX] Phone not reachable for sync")
            return
        }
        
        // CRITICAL SYNC FIX: Use multiple sync strategies simultaneously
        print("⌚ [CUSTOM-WORKOUT-SYNC-FIX] Requesting custom workouts using enhanced protocol...")
        
        // Strategy 1: Direct custom workout request with reply handler
        let message = [
            "action": "request_custom_workouts",
            "timestamp": Date().timeIntervalSince1970,
            "request_id": UUID().uuidString
        ] as [String: Any]
        
        WCSession.default.sendMessage(message, replyHandler: { reply in
            print("⌚ [CUSTOM-WORKOUT-SYNC-FIX] ✅ Sync request successful: \(reply)")
            
            // Handle sync response for custom workouts
            if let workoutsData = reply["workouts_data"] as? Data {
                do {
                    let customWorkouts = try JSONDecoder().decode([TrainingProgram].self, from: workoutsData)
                    DispatchQueue.main.async {
                        print("⌚ [CUSTOM-WORKOUT-SYNC-FIX] Received \(customWorkouts.count) custom workouts from iPhone")
                        
                        // CRITICAL: Update custom programs immediately
                        self.customPrograms = customWorkouts
                        self.saveCustomWorkouts()
                        
                        print("⌚ [CUSTOM-WORKOUT-SYNC-FIX] ✅ Successfully synced \(customWorkouts.count) custom workouts")
                        for workout in customWorkouts {
                            print("⌚ [CUSTOM-WORKOUT-SYNC-FIX]   - \(workout.name) (isCustom: \(workout.isCustom))")
                        }
                    }
                } catch {
                    print("❌ [CUSTOM-WORKOUT-SYNC-FIX] Failed to decode synced workouts: \(error)")
                }
            } else {
                print("⌚ [CUSTOM-WORKOUT-SYNC-FIX] No custom workouts data in response")
            }
        }) { error in
            print("❌ [CUSTOM-WORKOUT-SYNC-FIX] Failed to request sync: \(error.localizedDescription)")
            
            // Fallback Strategy 2: Try legacy sync method
            print("⌚ [CUSTOM-WORKOUT-SYNC-FIX] Trying fallback sync method...")
            let fallbackMessage = ["action": "sync_programs"]
            WCSession.default.sendMessage(fallbackMessage, replyHandler: nil) { fallbackError in
                print("❌ [CUSTOM-WORKOUT-SYNC-FIX] Fallback sync also failed: \(fallbackError.localizedDescription)")
                
                // Final Fallback Strategy 3: Use application context
                print("⌚ [CUSTOM-WORKOUT-SYNC-FIX] Requesting application context update...")
                let contextRequest = [
                    "action": "request_application_context_update",
                    "timestamp": Date().timeIntervalSince1970
                ] as [String: Any]
                
                WCSession.default.sendMessage(contextRequest, replyHandler: nil, errorHandler: nil)
            }
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
    
    // MARK: - Custom Workout Management
    
    private func deleteCustomPrograms(offsets: IndexSet) {
        let programsToDelete = offsets.map { customPrograms[$0] }
        
        for program in programsToDelete {
            // Remove from local array
            customPrograms.removeAll { $0.id == program.id }
            
            // Send deletion request to iPhone
            sendCustomWorkoutDeletion(program)
        }
    }
    
    private func requestCustomWorkoutCreation() {
        // Send request to iPhone to create new custom workout
        guard WCSession.default.isReachable else {
            print("⌚ Phone not reachable for custom workout creation")
            return
        }
        
        let message = [
            "action": "create_custom_workout",
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        WCSession.default.sendMessage(message, replyHandler: { reply in
            print("⌚ Custom workout creation request sent")
        }) { error in
            print("⌚ ❌ Failed to send custom workout creation request: \(error)")
        }
    }
    
    private func sendCustomWorkoutDeletion(_ program: TrainingProgram) {
        guard WCSession.default.isReachable else {
            print("⌚ Phone not reachable for custom workout deletion")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            let programData = try encoder.encode(program)
            
            let message = [
                "action": "delete_custom_workout",
                "workout_data": programData,
                "workout_id": program.id.uuidString,
                "timestamp": Date().timeIntervalSince1970
            ] as [String : Any]
            
            WCSession.default.sendMessage(message, replyHandler: { reply in
                print("⌚ ✅ Custom workout deletion sent to iPhone")
            }) { error in
                print("⌚ ❌ Failed to send custom workout deletion: \(error)")
            }
        } catch {
            print("⌚ ❌ Failed to encode custom workout for deletion: \(error)")
        }
    }
    
    // MARK: - Custom Workout Persistence
    
    private func loadCustomWorkouts() {
        print("⌚ [DEBUG] loadCustomWorkouts() called")
        
        // Load custom workouts from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "customWorkouts_watch"),
           let workouts = try? JSONDecoder().decode([TrainingProgram].self, from: data) {
            customPrograms = workouts
            print("⌚ ✅ Loaded \(workouts.count) custom workouts from local storage")
            for workout in workouts {
                print("⌚   - \(workout.name) (isCustom: \(workout.isCustom))")
            }
        } else {
            print("⌚ ⚠️ No custom workouts found in local storage")
        }
        
        // Also try to load from legacy key
        if let legacyData = UserDefaults.standard.data(forKey: "customPrograms"),
           let legacyWorkouts = try? JSONDecoder().decode([TrainingProgram].self, from: legacyData) {
            let filteredLegacy = legacyWorkouts.filter { $0.isCustom }
            if !filteredLegacy.isEmpty {
                print("⌚ Found \(filteredLegacy.count) custom workouts in legacy storage, migrating...")
                customPrograms.append(contentsOf: filteredLegacy)
                saveCustomWorkouts() // Save to new key
            }
        }
        
        // Request sync from iPhone if we have a connection
        print("⌚ [DEBUG] Connection status: \(isConnectedToPhone)")
        if isConnectedToPhone {
            print("⌚ [DEBUG] Requesting program sync...")
            requestProgramSync()
        } else {
            print("⌚ [DEBUG] Not connected to phone, skipping sync request")
        }
        
        // Force immediate sync attempt regardless of connection status
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("⌚ [DEBUG] Attempting forced sync after 1 second...")
            self.requestProgramSync()
        }
    }
    
    private func saveCustomWorkouts() {
        // Save custom workouts to UserDefaults
        do {
            let data = try JSONEncoder().encode(customPrograms)
            UserDefaults.standard.set(data, forKey: "customWorkouts_watch")
            print("⌚ Saved \(customPrograms.count) custom workouts to local storage")
        } catch {
            print("❌ Failed to save custom workouts: \(error)")
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

// MARK: - Simple Workout Row for watchOS

struct SimpleWorkoutRow: View {
    let program: TrainingProgram
    let isCustom: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(program.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                if isCustom {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
                
                DifficultyBadge(difficulty: program.difficulty)
            }
            
            HStack {
                Text("\(Int(program.totalDuration))min")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.1f km", program.distance))
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("\(program.estimatedCalories) cal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct QuickStat: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - WorkoutView

struct WorkoutView: View {
    let program: TrainingProgram
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var currentTab = 0
    
    var body: some View {
        TabView(selection: $currentTab) {
            // Timer & Metrics View (Combined)
            TimerMetricsView(program: program)
                .tag(0)
            
            // Controls View
            WorkoutControlsView(program: program)
                .tag(1)
        }
        .tabViewStyle(PageTabViewStyle())
        .navigationBarHidden(true)
        .onAppear {
            // Workout already started when button was pressed - no need to start again
            print("📱 [DEBUG] WorkoutView appeared, workout should already be active: \(workoutManager.isWorkoutActive)")
            workoutManager.debugTimerState()
        }
        .onDisappear {
            // Keep workout running when view disappears - workout continues in background
        }
    }
}

// MARK: - Combined Timer & Metrics View (2-Tab MVP Design)
struct TimerMetricsView: View {
    let program: TrainingProgram
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Current Activity Header
                currentActivityHeader
                
                // Main Timer Circle
                mainTimerCircle
                
                // Current Interval Progress
                intervalProgress
                
                // Compact Metrics Row
                compactMetricsRow
                
                // Quick Actions
                quickActions
            }
            .padding()
            .background(backgroundColor)
        }
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
            
            // Timer Text - FIXED: Now uses workoutManager.formattedRemainingTime
            VStack(spacing: 4) {
                // Current Activity (Walk/Run)
                Text(workoutManager.currentInterval?.type.displayName.uppercased() ?? "READY")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(currentActivityColor)
                
                Text(workoutManager.formattedRemainingTime)
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
            // Distance Progress (PRIMARY GOAL)
            VStack(spacing: 4) {
                HStack {
                    Text("Distance Goal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(workoutManager.formattedDistanceProgress)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(workoutManager.isDistanceGoalReached ? .green : .blue)
                }
                
                ProgressView(value: workoutManager.distanceProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: workoutManager.isDistanceGoalReached ? .green : .blue))
                    .scaleEffect(y: 1.5)
                
                if workoutManager.isDistanceGoalReached {
                    Text("🎯 GOAL REACHED!")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            
            // Total Program Progress (time-based for reference)
            VStack(spacing: 4) {
                HStack {
                    Text("Workout Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(workoutManager.formattedElapsedTime)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
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
    
    // MARK: - Compact Metrics Row (All Metrics Fit on Screen)
    private var compactMetricsRow: some View {
        VStack(spacing: 8) {
            // Primary metrics row
            HStack {
                CompactMetricView(
                    value: "\(Int(workoutManager.heartRate))",
                    unit: "BPM",
                    label: "HR",
                    color: .red
                )
                
                Divider().frame(height: 30)
                
                CompactMetricView(
                    value: "\(Int(workoutManager.activeCalories))",
                    unit: "CAL",
                    label: "CALS",
                    color: .orange
                )
                
                Divider().frame(height: 30)
                
                CompactMetricView(
                    value: workoutManager.formattedElapsedTime,
                    unit: "",
                    label: "TIME",
                    color: .blue
                )
            }
            
            // Secondary metrics row (Speed & Distance)
            HStack {
                CompactMetricView(
                    value: workoutManager.formattedSpeed,
                    unit: "km/h",
                    label: "SPEED",
                    color: .green
                )
                
                Divider().frame(height: 30)
                
                CompactMetricView(
                    value: workoutManager.formattedPace,
                    unit: "min/km",
                    label: "PACE",
                    color: .purple
                )
                
                Divider().frame(height: 30)
                
                CompactMetricView(
                    value: String(format: "%.2f", workoutManager.distance / 1000),
                    unit: "km",
                    label: "DIST",
                    color: .cyan
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
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
        case .run:
            return "Running 🏃‍♂️"
        case .walk:
            return "Walking 🚶‍♂️"
        }
    }
    
    private var currentActivityColor: Color {
        guard let currentInterval = workoutManager.currentInterval else {
            return .gray
        }
        
        switch currentInterval.type {
        case .run:
            return .red
        case .walk:
            return .blue
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

struct CompactMetricView: View {
    let value: String
    let unit: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.headline)
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
        .frame(maxWidth: .infinity)
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
