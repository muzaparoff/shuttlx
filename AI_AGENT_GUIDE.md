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

### Core Data Models

**File: `ShuttlX/Models/TrainingProgram.swift`**
```swift
import Foundation
import CloudKit

struct TrainingProgram: Identifiable, Codable {
    let id = UUID()
    var name: String
    var intervals: [TrainingInterval]
    var maxPulse: Int
    var createdDate: Date
    var lastModified: Date
    
    // CloudKit integration
    var recordID: CKRecord.ID?
}
```

**File: `ShuttlX/Models/TrainingInterval.swift`**
```swift
import Foundation

struct TrainingInterval: Identifiable, Codable {
    let id = UUID()
    var type: IntervalType
    var duration: TimeInterval // in seconds
    var targetPace: TrainingPace?
}

enum IntervalType: String, CaseIterable, Codable {
    case walk = "Walk"
    case run = "Run"
    case rest = "Rest"
}

enum TrainingPace: String, CaseIterable, Codable {
    case easy = "Easy"
    case moderate = "Moderate"
    case intense = "Intense"
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
    @State private var newIntervalType = IntervalType.walk
    @State private var newIntervalDuration: Double = 60
    
    init(program: TrainingProgram?) {
        _program = State(initialValue: program ?? TrainingProgram(
            name: "",
            intervals: [],
            maxPulse: 180,
            createdDate: Date(),
            lastModified: Date()
        ))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Program Details") {
                    TextField("Program Name", text: $program.name)
                    Stepper("Max Pulse: \(program.maxPulse)", value: $program.maxPulse, in: 100...220)
                }
                
                Section("Intervals") {
                    ForEach(program.intervals) { interval in
                        IntervalRowView(interval: interval)
                    }
                    .onDelete(perform: deleteInterval)
                    
                    HStack {
                        Picker("Type", selection: $newIntervalType) {
                            ForEach(IntervalType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        
                        Stepper("\(Int(newIntervalDuration))s", value: $newIntervalDuration, in: 10...3600, step: 10)
                        
                        Button("Add") {
                            addInterval()
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
                    .disabled(program.name.isEmpty || program.intervals.isEmpty)
                }
            }
        }
    }
    
    private func addInterval() {
        let interval = TrainingInterval(
            type: newIntervalType,
            duration: newIntervalDuration,
            targetPace: nil
        )
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
        VStack(spacing: 8) {
            // Main timer display (large, central)
            AppleStyleTimerView()
            
            // Current interval indicator (compact)
            if let currentInterval = workoutManager.currentInterval {
                CurrentIntervalView(interval: currentInterval)
            }
            
            // Metrics in a clean grid layout (heart rate, calories, distance)
            MetricsGridView()
            
            // Control buttons (start/pause, end)
            WorkoutControlsView()
        }
        .navigationTitle(workoutManager.currentProgram?.name ?? "Training")
        .navigationBarTitleDisplayMode(.inline)
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
    @Published var isRunning = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var heartRate: Double = 0
    
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var timer: Timer?
    
    func loadPrograms() {
        // Load programs from WatchConnectivity or local storage
    }
    
    func selectProgram(_ program: TrainingProgram) {
        currentProgram = program
        currentInterval = program.intervals.first
    }
    
    func toggleWorkout() {
        if isRunning {
            pauseWorkout()
        } else {
            startWorkout()
        }
    }
    
    private func startWorkout() {
        // Start HealthKit workout session
        isRunning = true
        startTimer()
    }
    
    private func pauseWorkout() {
        isRunning = false
        pauseTimer()
    }
    
    func endWorkout() {
        isRunning = false
        stopTimer()
        saveWorkoutSession()
        currentProgram = nil
        currentInterval = nil
        elapsedTime = 0
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.elapsedTime += 1
            self.checkIntervalProgress()
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
    
    private func checkIntervalProgress() {
        guard let program = currentProgram,
              let currentIndex = program.intervals.firstIndex(where: { $0.id == currentInterval?.id }) else {
            return
        }
        
        let intervalElapsed = elapsedTime - TimeInterval(currentIndex) * (currentInterval?.duration ?? 0)
        
        if intervalElapsed >= currentInterval?.duration ?? 0 {
            // Move to next interval
            let nextIndex = currentIndex + 1
            if nextIndex < program.intervals.count {
                currentInterval = program.intervals[nextIndex]
            } else {
                // Workout complete
                endWorkout()
            }
        }
    }
    
    private func saveWorkoutSession() {
        // Save completed session data
    }
}
```

## PHASE 3: IMPLEMENTATION SEQUENCE

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
