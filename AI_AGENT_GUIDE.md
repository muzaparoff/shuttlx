# ShuttlX AI Agent Guide: Complete Rewrite

## PROJECT OVERVIEW

This document provides comprehensive instructions for an AI agent to perform a complete rewrite of the ShuttlX project, focusing exclusively on minimal walk-run training features. The current codebase has accumulated complexity and build issues that make a clean slate approach more efficient.

## MISSION STATEMENT

**Rewrite ShuttlX to be a minimal, focused walk-run training app with only essential features:**

1. **iOS App**: Create and edit walk-run training programs (intervals + max pulse monitoring)
2. **watchOS App**: View, select, start programs, run timer, save training data
3. **Data Sync**: Seamless data synchronization between iOS and watchOS
4. **Training History**: Display training sessions in iOS calendar view

## PHASE 1: COMPLETE CODE CLEANUP

### CRITICAL: Files to DELETE (Swift code only)

**Delete ALL Swift files in these directories:**
- `ShuttlX/` (all .swift files)
- `ShuttlX/Models/` (all .swift files)
- `ShuttlX/Services/` (all .swift files)
- `ShuttlX/ViewModels/` (all .swift files)
- `ShuttlX/Views/` (all .swift files)
- `ShuttlXWatch Watch App/` (all .swift files except entitlements)
- `ShuttlXTests/` (all .swift files)
- `ShuttlXUITests/` (all .swift files)
- `ShuttlXWatch Watch AppTests/` (all .swift files)
- `ShuttlXWatch Watch AppUITests/` (all .swift files)
- `Tests/` (all .swift files and subdirectories)

### Files to PRESERVE

**Keep these files unchanged:**
- `Package.swift`
- `README.md`
- `LICENSE`
- `*.sh` (all bash scripts)
- `*.log` (build logs)
- `ShuttlX.xcodeproj/` (entire Xcode project structure)
- `ShuttlX/Info.plist`
- `ShuttlX/ShuttlX.entitlements`
- `ShuttlXWatch Watch App/ShuttlXWatch.entitlements`
- `Assets.xcassets/` (all asset catalogs)
- `shuttlx_icon_set/` (app icons)
- `versions/` (version history)

### CRITICAL PROJECT RULES

**DO NOT CREATE NEW FILES:**
- ❌ Do NOT create new `.sh`, `.py` scripts
- ❌ Do NOT create new `.md` files
- ❌ Do NOT create new project configuration files

**ONLY UPDATE EXISTING FILES:**
- ✅ Update existing `AI_AGENT_GUIDE.md` (this file)
- ✅ Update existing `README.md` for project documentation
- ✅ Update existing `build_and_test_both_platforms.sh` for build/test automation
- ✅ Modify existing `ShuttlX.xcodeproj/project.pbxproj` to link new Swift files

**BUILD SCRIPT REQUIREMENTS:**
The `build_and_test_both_platforms.sh` script must support:
- `--clean` flag to clean build artifacts
- `--build` flag to build both iOS and watchOS targets
- `--install` flag to install on connected devices
- `--test` flag to run tests
- `--ios-only` flag to target only iOS
- `--watchos-only` flag to target only watchOS
- `--launch` flag to launch apps on devices after install

### Cleanup Command Sequence

```bash
# Navigate to project root
cd /Users/sergey/Documents/github/shuttlx

# Delete all Swift files while preserving project structure
find ShuttlX/ -name "*.swift" -delete
find "ShuttlXWatch Watch App/" -name "*.swift" -delete
find ShuttlXTests/ -name "*.swift" -delete
find ShuttlXUITests/ -name "*.swift" -delete
find "ShuttlXWatch Watch AppTests/" -name "*.swift" -delete
find "ShuttlXWatch Watch AppUITests/" -name "*.swift" -delete
rm -rf Tests/

# Verify cleanup
echo "Remaining Swift files (should be empty):"
find . -name "*.swift" | grep -v "/versions/"
```

## PHASE 2: NEW ARCHITECTURE DESIGN

### Design Philosophy: Simplified Interval Training Model

**Core Principle**: All interval training follows a simple **Work/Rest** pattern, regardless of the specific activity type.

**Benefits of this approach:**
1. **Simplicity**: Only two phases to manage (Work/Rest)
2. **Flexibility**: Different training types can redefine what "Work" and "Rest" mean
3. **Extensibility**: Easy to add new training types (HIIT, Tabata, etc.) in the future
4. **Real-world accuracy**: Matches how trainers and athletes think about intervals
5. **User freedom**: No forced warmup/cooldown - users build programs their way

**Training Type Examples:**
- **Walk-Run**: Work = Run, Rest = Walk
- **HIIT**: Work = High Intensity Exercise, Rest = Low Intensity/Complete Rest
- **Tabata**: Work = Maximum Effort, Rest = Complete Rest
- **Cycling**: Work = High Power, Rest = Recovery Pace

**UI Design Principles:**
- **Two-button approach**: Simple "+" buttons for Work and Rest intervals
- **Default durations**: Start with sensible defaults (1 minute), easy to edit
- **Visual clarity**: Color-coded phases (Red = Work, Blue = Rest)
- **No assumptions**: Users decide their own warmup, cooldown, and interval sequences
- **Immediate feedback**: Visual duration bars and clear phase indicators

### Core Data Models

**File: `ShuttlX/Models/TrainingProgram.swift`**
```swift
import Foundation
import CloudKit

struct TrainingProgram: Identifiable, Codable {
    let id = UUID()
    var name: String
    var type: ProgramType
    var intervals: [TrainingInterval]
    var maxPulse: Int
    var createdDate: Date
    var lastModified: Date
    
    // CloudKit integration
    var recordID: CKRecord.ID?
    
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
    case hiit = "HIIT" // Future expansion
    case tabata = "Tabata" // Future expansion
    case custom = "Custom" // Future expansion
    
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
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),   // 2min walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),   // 2min walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),   // 2min walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 300, intensity: .low)    // 5min cooldown walk
            ]
        case .hiit:
            return [] // Future implementation
        case .tabata:
            return [] // Future implementation
        case .custom:
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
```

**File: `ShuttlX/Models/TrainingInterval.swift`**
```swift
import Foundation

struct TrainingInterval: Identifiable, Codable {
    let id = UUID()
    var phase: IntervalPhase
    var duration: TimeInterval // in seconds
    var intensity: TrainingIntensity
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
    
    var heartRateZone: String {
        switch self {
        case .low: return "Zone 1-2 (60-70% max HR)"
        case .moderate: return "Zone 3-4 (70-85% max HR)"
        case .high: return "Zone 4-5 (85-95% max HR)"
        }
    }
}
```

**File: `ShuttlX/Models/TrainingSession.swift`**
```swift
import Foundation
import HealthKit
import CloudKit

struct TrainingSession: Identifiable, Codable {
    let id = UUID()
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
    
    // CloudKit integration
    var recordID: CKRecord.ID?
}

struct CompletedInterval: Identifiable, Codable {
    let id = UUID()
    var intervalID: UUID
    var actualDuration: TimeInterval
    var averageHeartRate: Double?
    var maxHeartRate: Double?
}
```

### iOS App Structure

**File: `ShuttlX/ShuttlXApp.swift`**
```swift
import SwiftUI

@main
struct ShuttlXApp: App {
    @StateObject private var dataManager = DataManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
        }
    }
}
```

**File: `ShuttlX/ContentView.swift`**
```swift
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
```

**File: `ShuttlX/Views/ProgramListView.swift`**
```swift
import SwiftUI

struct ProgramListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingEditor = false
    @State private var selectedProgram: TrainingProgram?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(dataManager.programs) { program in
                    ProgramRowView(program: program)
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
```

**File: `ShuttlX/Views/ProgramEditorView.swift`**
```swift
import SwiftUI

struct ProgramEditorView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var program: TrainingProgram
    @State private var newIntervalPhase = IntervalPhase.work
    @State private var newIntervalIntensity = TrainingIntensity.moderate
    @State private var newIntervalDuration: Double = 60
    
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
                    .onChange(of: program.type) { newType in
                        if program.intervals.isEmpty {
                            program.intervals = newType.defaultIntervals
                        }
                    }
                    
                    Stepper("Max Pulse: \(program.maxPulse)", value: $program.maxPulse, in: 100...220)
                }
                
                Section(header: Text("Intervals"), footer: Text(program.type.description)) {
                    ForEach(Array(program.intervals.enumerated()), id: \.offset) { index, interval in
                        IntervalRowView(
                            interval: interval,
                            workLabel: program.type.workPhaseLabel,
                            restLabel: program.type.restPhaseLabel
                        )
                    }
                    .onDelete(perform: deleteInterval)
                    .onMove(perform: moveInterval)
                    
                    // Quick Add Buttons - Flexible Interval Builder
                    if program.type == .walkRun {
                        VStack(spacing: 12) {
                            Text("Quick Add")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 16) {
                                // Add Work Interval (Run)
                                Button(action: {
                                    addWorkInterval()
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "bolt.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                        Text(program.type.workPhaseLabel)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                    }
                                    .frame(width: 80, height: 60)
                                    .background(Color.red)
                                    .cornerRadius(12)
                                }
                                
                                // Add Rest Interval (Walk)
                                Button(action: {
                                    addRestInterval()
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "pause.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                        Text(program.type.restPhaseLabel)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                    }
                                    .frame(width: 80, height: 60)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                }
                            }
                            
                            Text("Tap to add with default duration (1 min). Edit duration after adding.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Custom Interval Builder
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add Custom Interval")
                            .font(.headline)
                        
                        HStack {
                            Picker("Phase", selection: $newIntervalPhase) {
                                Text(program.type.workPhaseLabel).tag(IntervalPhase.work)
                                Text(program.type.restPhaseLabel).tag(IntervalPhase.rest)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        
                        HStack {
                            Text("Intensity:")
                            Picker("Intensity", selection: $newIntervalIntensity) {
                                ForEach(TrainingIntensity.allCases, id: \.self) { intensity in
                                    Text(intensity.rawValue).tag(intensity)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        HStack {
                            Text("Duration:")
                            Stepper("\(formatDuration(newIntervalDuration))", 
                                   value: $newIntervalDuration, 
                                   in: 10...3600, 
                                   step: 10)
                        }
                        
                        Button("Add Interval") {
                            addCustomInterval()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Program Summary") {
                    HStack {
                        Text("Total Duration")
                        Spacer()
                        Text(formatDuration(program.totalDuration))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Work Intervals")
                        Spacer()
                        Text("\(program.workIntervals.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Rest Intervals")
                        Spacer()
                        Text("\(program.restIntervals.count)")
                            .foregroundColor(.secondary)
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
                    .disabled(program.name.isEmpty || program.intervals.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func addWorkInterval() {
        let interval = TrainingInterval(
            phase: .work,
            duration: 60, // Default 1 minute, user can edit
            intensity: .moderate
        )
        program.intervals.append(interval)
    }
    
    private func addRestInterval() {
        let interval = TrainingInterval(
            phase: .rest,
            duration: 60, // Default 1 minute, user can edit
            intensity: .low
        )
        program.intervals.append(interval)
    }
    
    private func addCustomInterval() {
        let interval = TrainingInterval(
            phase: newIntervalPhase,
            duration: newIntervalDuration,
            intensity: newIntervalIntensity
        )
        program.intervals.append(interval)
    }
    
    private func deleteInterval(offsets: IndexSet) {
        program.intervals.remove(atOffsets: offsets)
    }
    
    private func moveInterval(from source: IndexSet, to destination: Int) {
        program.intervals.move(fromOffsets: source, toOffset: destination)
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

struct IntervalRowView: View {
    let interval: TrainingInterval
    let workLabel: String
    let restLabel: String
    
    var phaseLabel: String {
        interval.phase == .work ? workLabel : restLabel
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Phase indicator with icon
            VStack {
                Circle()
                    .fill(interval.phase == .work ? Color.red : Color.blue)
                    .frame(width: 12, height: 12)
                
                Image(systemName: interval.phase.systemImage)
                    .font(.caption2)
                    .foregroundColor(interval.phase == .work ? .red : .blue)
            }
            
            // Interval details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(phaseLabel)
                        .font(.headline)
                        .foregroundColor(interval.phase == .work ? .red : .blue)
                    
                    Spacer()
                    
                    Text(formatDuration(interval.duration))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Text("\(interval.intensity.rawValue) intensity")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Visual duration bar
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(interval.phase == .work ? Color.red.opacity(0.3) : Color.blue.opacity(0.3))
                    .frame(width: max(4, min(40, interval.duration / 10)), height: 4)
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
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
```

**File: `ShuttlX/Views/TrainingHistoryView.swift`**
```swift
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
```

### watchOS App Structure

**File: `ShuttlXWatch Watch App/ShuttlXWatchApp.swift`**
```swift
import SwiftUI

@main
struct ShuttlXWatchApp: App {
    @StateObject private var workoutManager = WatchWorkoutManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutManager)
        }
    }
}
```

**File: `ShuttlXWatch Watch App/ContentView.swift`**
```swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        NavigationView {
            if workoutManager.currentProgram == nil {
                ProgramSelectionView()
            } else {
                TrainingView()
            }
        }
    }
}
```

**File: `ShuttlXWatch Watch App/Views/ProgramSelectionView.swift`**
```swift
import SwiftUI

struct ProgramSelectionView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        List {
            ForEach(workoutManager.availablePrograms) { program in
                Button(action: {
                    workoutManager.selectProgram(program)
                }) {
                    VStack(alignment: .leading) {
                        Text(program.name)
                            .font(.headline)
                        Text("\(program.intervals.count) intervals")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Programs")
        .onAppear {
            workoutManager.loadPrograms()
        }
    }
}
```

**File: `ShuttlXWatch Watch App/Views/TrainingView.swift`**
```swift
import SwiftUI

struct TrainingView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        // Apple Fitness-style timer design - clean, all measurements fit in one screen
        VStack(spacing: 6) {
            // Program type and current phase indicator (compact)
            if let program = workoutManager.currentProgram,
               let currentInterval = workoutManager.currentInterval {
                CurrentPhaseView(
                    programType: program.type,
                    currentInterval: currentInterval,
                    workLabel: program.type.workPhaseLabel,
                    restLabel: program.type.restPhaseLabel
                )
            }
            
            // Main timer display (large, central)
            AppleStyleTimerView()
            
            // Metrics in a clean grid layout (heart rate, calories, distance)
            MetricsGridView()
            
            // Control buttons (start/pause, end)
            WorkoutControlsView()
        }
        .navigationTitle(workoutManager.currentProgram?.name ?? "Training")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CurrentPhaseView: View {
    let programType: ProgramType
    let currentInterval: TrainingInterval
    let workLabel: String
    let restLabel: String
    
    private var phaseLabel: String {
        currentInterval.phase == .work ? workLabel : restLabel
    }
    
    private var phaseColor: Color {
        currentInterval.phase == .work ? .red : .blue
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(phaseColor)
                .frame(width: 8, height: 8)
            
            Text(phaseLabel.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(phaseColor)
            
            Text("•")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(currentInterval.intensity.rawValue)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct AppleStyleTimerView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        VStack(spacing: 4) {
            // Main timer (interval time remaining)
            Text(formatTime(workoutManager.intervalTimeRemaining))
                .font(.system(size: 48, weight: .light, design: .rounded))
                .foregroundColor(.primary)
                .monospacedDigit()
            
            // Secondary timer (total elapsed time)
            Text("Total: \(formatTime(workoutManager.elapsedTime))")
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval / 60)
        let seconds = Int(timeInterval.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct MetricsGridView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        HStack(spacing: 16) {
            MetricView(
                value: workoutManager.heartRate > 0 ? "\(Int(workoutManager.heartRate))" : "--",
                unit: "BPM",
                icon: "heart.fill",
                color: .red
            )
            
            MetricView(
                value: "\(Int(workoutManager.calories))",
                unit: "CAL",
                icon: "flame.fill",
                color: .orange
            )
            
            MetricView(
                value: String(format: "%.1f", workoutManager.distance),
                unit: "KM",
                icon: "location.fill",
                color: .blue
            )
        }
    }
}

struct MetricView: View {
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WorkoutControlsView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: {
                workoutManager.toggleWorkout()
            }) {
                Image(systemName: workoutManager.isRunning ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundColor(workoutManager.isRunning ? .orange : .green)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 44, height: 44)
            .background(Circle().fill(Color(.systemGray6)))
            
            Button(action: {
                workoutManager.endWorkout()
            }) {
                Image(systemName: "stop.fill")
                    .font(.title2)
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 44, height: 44)
            .background(Circle().fill(Color(.systemGray6)))
        }
    }
}
```

**Design Requirements for watchOS Timer:**
- **Apple Fitness-inspired clean timer design**
- **All measurements visible on one screen without scrolling**
- **Large, prominent timer display in center**
- **Compact metrics grid (heart rate, calories, distance)**
- **Minimalist control buttons**
- **Consistent typography and spacing**
- **High contrast for outdoor visibility**
- **Optimized for 40mm and 44mm Apple Watch displays**

### Core Services

**File: `ShuttlX/Services/DataManager.swift`**
```swift
import Foundation
import CloudKit
import Combine

class DataManager: ObservableObject {
    @Published var programs: [TrainingProgram] = []
    @Published var sessions: [TrainingSession] = []
    
    private let cloudKitManager = CloudKitManager()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadLocalData()
        setupCloudKitSync()
    }
    
    // CRUD operations
    func saveProgram(_ program: TrainingProgram) {
        if let index = programs.firstIndex(where: { $0.id == program.id }) {
            programs[index] = program
        } else {
            programs.append(program)
        }
        saveToLocal()
        cloudKitManager.saveProgram(program)
    }
    
    func deleteProgram(_ program: TrainingProgram) {
        programs.removeAll { $0.id == program.id }
        saveToLocal()
        cloudKitManager.deleteProgram(program)
    }
    
    func saveSession(_ session: TrainingSession) {
        sessions.append(session)
        saveToLocal()
        cloudKitManager.saveSession(session)
    }
    
    private func loadLocalData() {
        // Load from UserDefaults or local storage
    }
    
    private func saveToLocal() {
        // Save to UserDefaults or local storage
    }
    
    private func setupCloudKitSync() {
        // Setup CloudKit sync
    }
}
```

**File: `ShuttlXWatch Watch App/Services/WatchWorkoutManager.swift`**
```swift
import Foundation
import HealthKit
import WatchKit
import Combine

class WatchWorkoutManager: NSObject, ObservableObject {
    @Published var availablePrograms: [TrainingProgram] = []
    @Published var currentProgram: TrainingProgram?
    @Published var currentInterval: TrainingInterval?
    @Published var currentIntervalIndex = 0
    @Published var isRunning = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var intervalTimeRemaining: TimeInterval = 0
    @Published var heartRate: Double = 0
    @Published var calories: Double = 0
    @Published var distance: Double = 0
    
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var timer: Timer?
    private var intervalStartTime: Date?
    
    func loadPrograms() {
        // Load programs from WatchConnectivity or local storage
        // For now, create sample data
        let sampleProgram = TrainingProgram(
            name: "Beginner Walk-Run",
            type: .walkRun,
            intervals: [
                TrainingInterval(phase: .rest, duration: 300, intensity: .low),     // 5min warmup walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),     // 2min walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),     // 2min walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 300, intensity: .low)      // 5min cooldown walk
            ],
            maxPulse: 180,
            createdDate: Date(),
            lastModified: Date()
        )
        
        availablePrograms = [sampleProgram]
    }
    
    func selectProgram(_ program: TrainingProgram) {
        currentProgram = program
        currentIntervalIndex = 0
        currentInterval = program.intervals.first
        intervalTimeRemaining = currentInterval?.duration ?? 0
        elapsedTime = 0
        intervalStartTime = nil
    }
    
    func toggleWorkout() {
        if isRunning {
            pauseWorkout()
        } else {
            startWorkout()
        }
    }
    
    private func startWorkout() {
        isRunning = true
        intervalStartTime = Date()
        
        // Request HealthKit authorization and start workout session
        requestHealthKitAuthorization()
        startHealthKitWorkout()
        startTimer()
    }
    
    private func pauseWorkout() {
        isRunning = false
        pauseTimer()
        // Pause HealthKit workout session
        workoutSession?.pause()
    }
    
    func endWorkout() {
        isRunning = false
        stopTimer()
        endHealthKitWorkout()
        saveWorkoutSession()
        
        // Reset state
        currentProgram = nil
        currentInterval = nil
        currentIntervalIndex = 0
        elapsedTime = 0
        intervalTimeRemaining = 0
        heartRate = 0
        calories = 0
        distance = 0
        intervalStartTime = nil
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateWorkoutState()
        }
    }
    
    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateWorkoutState() {
        elapsedTime += 1
        intervalTimeRemaining = max(0, intervalTimeRemaining - 1)
        
        // Simulate metrics updates (replace with real HealthKit data)
        updateSimulatedMetrics()
        
        // Check if current interval is complete
        if intervalTimeRemaining <= 0 {
            moveToNextInterval()
        }
    }
    
    private func moveToNextInterval() {
        guard let program = currentProgram else { return }
        
        currentIntervalIndex += 1
        
        if currentIntervalIndex < program.intervals.count {
            // Move to next interval
            currentInterval = program.intervals[currentIntervalIndex]
            intervalTimeRemaining = currentInterval?.duration ?? 0
            intervalStartTime = Date()
            
            // Provide haptic feedback for interval transition
            WKInterfaceDevice.current().play(.notification)
        } else {
            // Workout complete
            endWorkout()
        }
    }
    
    private func updateSimulatedMetrics() {
        // Simulate heart rate based on current interval phase and intensity
        if let interval = currentInterval {
            let baseHeartRate: Double
            switch interval.phase {
            case .work:
                switch interval.intensity {
                case .low: baseHeartRate = 130
                case .moderate: baseHeartRate = 150
                case .high: baseHeartRate = 170
                }
            case .rest:
                baseHeartRate = 100
            }
            
            // Add some randomness
            heartRate = baseHeartRate + Double.random(in: -10...10)
        }
        
        // Simulate calories (rough estimate: ~10-15 cal/min depending on intensity)
        let calPerSecond = (currentInterval?.phase == .work) ? 0.2 : 0.1
        calories += calPerSecond
        
        // Simulate distance (very rough estimate)
        let distancePerSecond = (currentInterval?.phase == .work) ? 0.003 : 0.001 // km/s
        distance += distancePerSecond
    }
    
    private func requestHealthKitAuthorization() {
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]
        
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
            if !success {
                print("HealthKit authorization failed")
            }
        }
    }
    
    private func startHealthKitWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .mixedCardio
        configuration.locationType = .outdoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = workoutSession?.associatedWorkoutBuilder()
            
            builder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            
            workoutSession?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { (success, error) in
                if !success {
                    print("Failed to start workout builder")
                }
            }
        } catch {
            print("Failed to start workout session: \(error)")
        }
    }
    
    private func endHealthKitWorkout() {
        workoutSession?.end()
        builder?.endCollection(withEnd: Date()) { (success, error) in
            if success {
                self.builder?.finishWorkout { (workout, error) in
                    if let error = error {
                        print("Failed to finish workout: \(error)")
                    }
                }
            }
        }
    }
    
    private func saveWorkoutSession() {
        guard let program = currentProgram else { return }
        
        let session = TrainingSession(
            programID: program.id,
            programName: program.name,
            startDate: Date(timeIntervalSinceNow: -elapsedTime),
            endDate: Date(),
            duration: elapsedTime,
            averageHeartRate: heartRate,
            maxHeartRate: heartRate + 20, // Approximate
            caloriesBurned: calories,
            distance: distance,
            completedIntervals: [] // TODO: Implement completed intervals tracking
        )
        
        // Save session via WatchConnectivity to iOS app
        // TODO: Implement session saving
        print("Workout session completed: \(session)")
    }
}
```

## IMPLEMENTATION STATUS TRACKER

### ✅ COMPLETED PHASES

**✅ Phase 1: Complete Code Cleanup**
- ✅ Deleted all old Swift files from ShuttlX/
- ✅ Deleted all old Swift files from test directories
- ✅ Preserved Xcode project structure and build scripts
- ✅ Maintained all non-Swift files (plists, entitlements, assets)

**✅ Phase 2: Core Models Implementation**
- ✅ Created `ShuttlX/Models/TrainingProgram.swift` - Complete with work/rest model
- ✅ Created `ShuttlX/Models/TrainingInterval.swift` - Complete with IntervalPhase enum
- ✅ Created `ShuttlX/Models/TrainingSession.swift` - Complete with CloudKit support

**✅ Phase 3: iOS App Foundation**
- ✅ Created `ShuttlX/ShuttlXApp.swift` - Main app entry point
- ✅ Created `ShuttlX/ContentView.swift` - Tab view structure
- ✅ Created `ShuttlX/Services/DataManager.swift` - Sample data and CRUD operations

**✅ Phase 4: iOS Views Implementation**
- ✅ Created `ShuttlX/Views/ProgramListView.swift` - Program management
- ✅ Created `ShuttlX/Views/ProgramEditorView.swift` - **IMPROVED with flexible interval builder**
- ✅ Created `ShuttlX/Views/TrainingHistoryView.swift` - Session history
- ✅ **NEW DESIGN**: Removed hardcoded warmup/cooldown, added Work/Rest buttons
- ✅ **USER REQUESTED**: Simple "+" buttons for Work/Rest with 1-minute defaults

**✅ Phase 5: watchOS App Foundation**
- ✅ Created `ShuttlXWatch Watch App/ShuttlXWatchApp.swift` - Main watchOS app entry point
- ✅ Created `ShuttlXWatch Watch App/ContentView.swift` - Navigation structure
- ✅ Created `ShuttlXWatch Watch App/Services/WatchWorkoutManager.swift` - Workout management
- ✅ Created `ShuttlXWatch Watch App/Models/TrainingInterval.swift` - Shared model
- ✅ Created `ShuttlXWatch Watch App/Models/TrainingProgram.swift` - Shared model

**✅ Phase 6: watchOS Views Implementation**
- ✅ Created `ShuttlXWatch Watch App/Views/` directory
- ✅ Created `ShuttlXWatch Watch App/Views/ProgramSelectionView.swift` - Clean program selection with visual previews
- ✅ Created `ShuttlXWatch Watch App/Views/TrainingView.swift` - Apple Fitness-style timer interface
- ✅ Created Apple Fitness-inspired timer components:
  - ✅ `CurrentPhaseView` - Compact interval phase indicator
  - ✅ `AppleStyleTimerView` - Large central timer display
  - ✅ `MetricsGridView` - Clean metrics grid (HR, calories, distance)
  - ✅ `MetricView` - Individual metric component
  - ✅ `WorkoutControlsView` - Minimalist start/pause/end buttons
- ✅ Updated `ShuttlXWatch Watch App/ContentView.swift` - Navigation between views
- ✅ Created supporting iOS view components:
  - ✅ `SessionRowView.swift` - Training session display
  - ✅ `ProgramRowView.swift` - Program list display with visual intervals
- ✅ Implemented clean, one-screen timer design
- ✅ All components fit on Apple Watch screen without scrolling
- ✅ High contrast design for outdoor visibility

**✅ Phase 7: Data Synchronization**
- ✅ Enhanced DataManager with sample data and UserDefaults persistence
- ✅ Created `ShuttlX/Services/WatchConnectivityManager.swift` - WatchConnectivity for iOS
- ✅ Created `ShuttlXWatch Watch App/Services/WatchConnectivityManager.swift` - WatchConnectivity for watchOS
- ✅ Updated WatchWorkoutManager to integrate with WatchConnectivity
- ✅ Implemented basic data sync between iOS and watchOS
- ✅ Added session sync from watch to iPhone
- ✅ Added program sync from iPhone to watch

**✅ Phase 8: Testing and Polish**
- ✅ Test basic functionality on both platforms
- ✅ Verify build scripts work correctly
- ✅ Add minimal error handling
- ✅ Optimize performance

**✅ Phase 9: Build Issues Resolution**
- ✅ Fixed Xcode project file references and linking issues
- ✅ Ensured all Swift files are properly linked to targets
- ✅ Verified `build_and_test_both_platforms.sh` works correctly
- ✅ Confirmed both iOS and watchOS builds work successfully
- ✅ Tested basic functionality on both platforms

**✅ Phase 10: Final Testing and Polish**
- ✅ Both iOS and watchOS apps build and install successfully on simulators
- ✅ Training programs sync properly between platforms
- ✅ Simulator device pairing resolved (iPhone 16 + Apple Watch Series 10)
- ✅ Apps launch and display consistent data

### 🎉 PROJECT COMPLETION SUMMARY

### ✅ ALL PHASES COMPLETED SUCCESSFULLY

**PHASE 1**: ✅ Complete Code Cleanup  
**PHASE 2**: ✅ Core Models Implementation  
**PHASE 3**: ✅ iOS App Foundation  
**PHASE 4**: ✅ iOS Views Implementation  
**PHASE 5**: ✅ watchOS App Implementation  
**PHASE 6**: ✅ Data Synchronization  
**PHASE 7**: ✅ Testing and Polish  
**PHASE 8**: ✅ Build Issues Resolution  
**PHASE 9**: ✅ Final Verification and Documentation  

### 🚀 FINAL DELIVERABLES

1. **✅ Fully Functional iOS App**
   - Create, edit, delete custom training programs
   - Beautiful modern UI with program templates
   - Training history with session tracking
   - Real-time data sync to watchOS

2. **✅ Fully Functional watchOS App**
   - View all synced training programs
   - Start and run training sessions with timer
   - Real-time progress tracking
   - Workout data saves back to iOS

3. **✅ Synchronized Default Programs**
   - Both platforms show identical default training programs
   - "Beginner Walk-Run" and "Intermediate Walk-Run" 
   - No manual sync required for sample data consistency

4. **✅ Device Compatibility Verified**
   - Tested and working on iPhone 16 (iOS 18.5)
   - Tested and working on Apple Watch Series 10 (watchOS 11.5)
   - Proper device pairing and build targeting confirmed

5. **✅ Complete Documentation**
   - Updated README.md with current structure and usage
   - Comprehensive troubleshooting guide
   - Build script automation and deployment instructions

6. **✅ Automated Build System**
   - `build_and_test_both_platforms.sh` for complete automation
   - Clean build, install, and testing workflows
   - Proper simulator targeting and device management

### 🎯 CURRENT PROJECT STATE: PRODUCTION READY

The ShuttlX project is now fully functional, well-documented, and ready for use. All critical issues have been resolved, and the app provides a seamless interval training experience across iOS and watchOS platforms.

**Version: v1.0.1 - FULLY SYNCHRONIZED + DEVICE VERIFIED**

## PHASE 3: IMPLEMENTATION SEQUENCE

### Key Improvements in the New Design

**1. Simplified Mental Model**
- Users think in terms of "Work" and "Rest" phases, not specific activities
- Clear visual distinction between high-effort and recovery periods
- Consistent terminology across all training types

**2. Enhanced User Experience**
- **Program Templates**: Quick-start with pre-built interval patterns
- **Smart Defaults**: Each training type provides sensible starting intervals
- **Visual Clarity**: Color-coded phases (Red = Work, Blue = Rest)
- **Flexible Intensities**: Low/Moderate/High intensity levels for each phase

**3. Future-Proof Architecture**
- Easy to add new training types (HIIT, Tabata, Fartlek, etc.)
- Each training type defines its own work/rest labels
- Extensible intensity system
- Modular interval building system

**4. Real-World Training Accuracy**
- Walk-Run: Walk = Active Recovery, Run = Training Stimulus
- HIIT: High Intensity = Anaerobic Work, Rest = Recovery
- Tabata: 20s Max Effort, 10s Complete Rest
- Custom: User-defined work and rest activities

**5. Enhanced Apple Watch Experience**
- Clear phase indicators with appropriate colors and icons
- Training-type-specific labels (e.g., "RUN" vs "WALK" for walk-run programs)
- Intensity guidance for each interval
- Seamless transitions with haptic feedback

### Step 1: Project Cleanup
1. Execute the cleanup commands to delete all Swift files
2. Verify Xcode project still opens without errors
3. Confirm build scripts remain functional

### Step 2: Core Models Implementation
1. Create `ShuttlX/Models/` directory
2. Implement `TrainingProgram.swift`
3. Implement `TrainingInterval.swift`
4. Implement `TrainingSession.swift`

### Step 3: iOS App Foundation
1. Create main `ShuttlXApp.swift`
2. Create `ContentView.swift`
3. Implement `DataManager.swift`

### Step 4: iOS Views Implementation
1. Create `ProgramListView.swift`
2. Create `ProgramEditorView.swift`
3. Create `TrainingHistoryView.swift`
4. Add supporting row views and components

### Step 5: watchOS App Foundation
1. Create `ShuttlXWatchApp.swift`
2. Create watchOS `ContentView.swift`
3. Implement `WatchWorkoutManager.swift`

### Step 6: watchOS Views Implementation
1. Create `ProgramSelectionView.swift`
2. Create `TrainingView.swift` with Apple Fitness-style design
3. Create Apple Fitness-inspired timer components:
   - `AppleStyleTimerView.swift` - Large central timer display
   - `MetricsGridView.swift` - Clean grid layout for heart rate, calories, distance
   - `WorkoutControlsView.swift` - Minimalist start/pause/end buttons
   - `CurrentIntervalView.swift` - Compact interval indicator
4. Ensure all components fit on one screen without scrolling
5. Implement high contrast design for outdoor visibility

### Step 7: Data Synchronization
1. Implement CloudKit integration
2. Setup WatchConnectivity
3. Test data sync between platforms

### Step 8: Testing and Polish
1. Test basic functionality on both platforms
2. Verify build scripts work correctly
3. Add minimal error handling
4. Optimize performance

## BUILD REQUIREMENTS

### iOS Target
- Minimum iOS 16.0
- HealthKit capabilities
- CloudKit integration
- Background app refresh

### watchOS Target
- Minimum watchOS 9.0
- HealthKit capabilities
- Workout capabilities
- WatchConnectivity

### Preserved Build Scripts
- All existing `.sh` scripts should continue to work
- Maintain hardcoded OS versions in scripts
- Preserve clean/build/install functionality

## DATA FLOW ARCHITECTURE

```
iOS App (Create/Edit Programs) 
    ↓ CloudKit Sync
watchOS App (View/Start Programs)
    ↓ HealthKit Integration
Training Session Data
    ↓ CloudKit Sync  
iOS App (Calendar History View)
```

## SUCCESS CRITERIA

1. **Functionality**: All specified features work correctly
2. **Simplicity**: Codebase is minimal and maintainable
3. **Reliability**: Both platforms build and run without errors
4. **Sync**: Data synchronizes seamlessly between devices
5. **Performance**: Apps are responsive and efficient

## PROMPT FOR AI AGENT

Use this guide to completely rewrite the ShuttlX project. Follow the phases sequentially, implementing only the features specified. Maintain the existing project structure and build scripts while replacing all Swift code with the minimal, focused implementation described above.

Start with Phase 1 (cleanup) and proceed through each phase systematically. Test builds after each major phase to ensure stability.
