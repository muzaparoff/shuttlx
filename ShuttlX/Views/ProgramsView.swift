//
//  ProgramsView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/9/25.
//

import SwiftUI

// MARK: - Training Program Model for iOS

struct TrainingProgram: Identifiable, Codable {
    var id = UUID()
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
        targetHeartRateZone: HeartRateZone = .zone3,
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
    
    // Computed properties for display
    var intervalPattern: String {
        return "\(String(format: "%.1f", runInterval))min run / \(String(format: "%.1f", walkInterval))min walk"
    }
    
    var formattedDistance: String {
        return "\(String(format: "%.1f", distance)) km"
    }
    
    var formattedDuration: String {
        return "\(Int(totalDuration)) min"
    }
}

enum TrainingDifficulty: String, CaseIterable, Codable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"
    
    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        case .expert: return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .beginner: return "leaf.circle.fill"
        case .intermediate: return "flame.circle.fill"
        case .advanced: return "bolt.circle.fill"
        case .expert: return "crown.circle.fill"
        }
    }
}

// MARK: - Programs View

struct ProgramsView: View {
    @State private var trainingPrograms: [TrainingProgram] = defaultTrainingPrograms
    @State private var customPrograms: [TrainingProgram] = []
    @State private var showingAddProgram = false
    @State private var selectedProgram: TrainingProgram?
    @State private var showingProgramDetail = false
    @EnvironmentObject private var serviceLocator: ServiceLocator
    
    var allPrograms: [TrainingProgram] {
        return trainingPrograms + customPrograms
    }
    
    var body: some View {
        NavigationView {
            List {
                // Default Programs Section
                if !trainingPrograms.isEmpty {
                    Section("Default Programs") {
                        ForEach(trainingPrograms) { program in
                            ProgramRow(program: program) {
                                selectedProgram = program
                                showingProgramDetail = true
                            }
                        }
                    }
                }
                
                // Custom Programs Section
                if !customPrograms.isEmpty {
                    Section("Custom Programs") {
                        ForEach(customPrograms) { program in
                            ProgramRow(program: program) {
                                selectedProgram = program
                                showingProgramDetail = true
                            }
                        }
                        .onDelete(perform: deleteCustomPrograms)
                    }
                } else {
                    Section("Custom Programs") {
                        Text("No custom programs yet")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
            .navigationTitle("Training Programs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddProgram = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddProgram) {
                AddProgramView { newProgram in
                    customPrograms.append(newProgram)
                    savePrograms()
                    syncProgramsToWatch()
                }
            }
            .sheet(isPresented: $showingProgramDetail) {
                if let program = selectedProgram {
                    ProgramDetailView(
                        program: program,
                        isCustom: program.isCustom,
                        onUpdate: { updatedProgram in
                            updateProgram(updatedProgram)
                        },
                        onDelete: {
                            deleteProgram(program)
                        }
                    )
                }
            }
        }
        .onAppear {
            loadPrograms()
        }
    }
    
    private func deleteCustomPrograms(offsets: IndexSet) {
        customPrograms.remove(atOffsets: offsets)
        savePrograms()
        syncProgramsToWatch()
    }
    
    private func updateProgram(_ updatedProgram: TrainingProgram) {
        if updatedProgram.isCustom {
            if let index = customPrograms.firstIndex(where: { $0.id == updatedProgram.id }) {
                customPrograms[index] = updatedProgram
            }
        } else {
            if let index = trainingPrograms.firstIndex(where: { $0.id == updatedProgram.id }) {
                trainingPrograms[index] = updatedProgram
            }
        }
        savePrograms()
        syncProgramsToWatch()
    }
    
    private func deleteProgram(_ program: TrainingProgram) {
        if program.isCustom {
            customPrograms.removeAll { $0.id == program.id }
        } else {
            trainingPrograms.removeAll { $0.id == program.id }
        }
        savePrograms()
        syncProgramsToWatch()
    }
    
    private func savePrograms() {
        // Save to UserDefaults for persistence
        let encoder = JSONEncoder()
        if let customData = try? encoder.encode(customPrograms) {
            UserDefaults.standard.set(customData, forKey: "customPrograms")
        }
        if let defaultData = try? encoder.encode(trainingPrograms) {
            UserDefaults.standard.set(defaultData, forKey: "defaultPrograms")
        }
    }
    
    private func loadPrograms() {
        // Load from UserDefaults
        let decoder = JSONDecoder()
        
        if let customData = UserDefaults.standard.data(forKey: "customPrograms"),
           let loadedCustom = try? decoder.decode([TrainingProgram].self, from: customData) {
            customPrograms = loadedCustom
        }
        
        if let defaultData = UserDefaults.standard.data(forKey: "defaultPrograms"),
           let loadedDefault = try? decoder.decode([TrainingProgram].self, from: defaultData) {
            trainingPrograms = loadedDefault
        } else {
            // First time - use default programs
            trainingPrograms = defaultTrainingPrograms
        }
    }
    
    private func syncProgramsToWatch() {
        // Sync programs to Apple Watch
        let allPrograms = trainingPrograms + customPrograms
        print("Syncing \(allPrograms.count) training programs to watch")
        
        // Encode programs to send to watch
        do {
            let data = try JSONEncoder().encode(allPrograms)
            let contextData = ["training_programs": data]
            serviceLocator.watchManager.sendWorkoutData(contextData)
            print("Successfully sent training programs to watch")
        } catch {
            print("Failed to encode training programs: \(error)")
        }
    }
}

// MARK: - Program Row

struct ProgramRow: View {
    let program: TrainingProgram
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(program.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    DifficultyBadge(difficulty: program.difficulty)
                }
                
                Text(program.intervalPattern)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Label(program.formattedDistance, systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Label(program.formattedDuration, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Label("\(program.estimatedCalories) cal", systemImage: "flame")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Difficulty Badge

struct DifficultyBadge: View {
    let difficulty: TrainingDifficulty
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: difficulty.icon)
                .font(.caption)
            Text(difficulty.rawValue.capitalized)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(difficulty.color.opacity(0.2))
        .foregroundColor(difficulty.color)
        .clipShape(Capsule())
    }
}

// MARK: - Add Program View

struct AddProgramView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var distance: Double = 5.0
    @State private var runInterval: Double = 2.0
    @State private var walkInterval: Double = 1.0
    @State private var totalDuration: Double = 30.0
    @State private var difficulty: TrainingDifficulty = .beginner
    @State private var description = ""
    @State private var estimatedCalories: Int = 300
    @State private var targetHeartRateZone: HeartRateZone = .zone3
    
    let onSave: (TrainingProgram) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Program Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Intervals") {
                    HStack {
                        Text("Run Interval")
                        Spacer()
                        Text("\(String(format: "%.1f", runInterval)) min")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $runInterval, in: 0.5...10.0, step: 0.5)
                    
                    HStack {
                        Text("Walk Interval")
                        Spacer()
                        Text("\(String(format: "%.1f", walkInterval)) min")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $walkInterval, in: 0.5...5.0, step: 0.5)
                }
                
                Section("Workout Details") {
                    HStack {
                        Text("Total Duration")
                        Spacer()
                        Text("\(Int(totalDuration)) min")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $totalDuration, in: 10...120, step: 5)
                    
                    HStack {
                        Text("Distance")
                        Spacer()
                        Text("\(String(format: "%.1f", distance)) km")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $distance, in: 1.0...20.0, step: 0.5)
                    
                    HStack {
                        Text("Estimated Calories")
                        Spacer()
                        Text("\(estimatedCalories)")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(estimatedCalories) },
                        set: { estimatedCalories = Int($0) }
                    ), in: 100...1000, step: 25)
                }
                
                Section("Difficulty & Target") {
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(TrainingDifficulty.allCases, id: \.self) { level in
                            Text(level.rawValue.capitalized).tag(level)
                        }
                    }
                    
                    Picker("Heart Rate Zone", selection: $targetHeartRateZone) {
                        ForEach(HeartRateZone.allCases, id: \.self) { zone in
                            Text(zone.rawValue.capitalized).tag(zone)
                        }
                    }
                }
            }
            .navigationTitle("New Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let program = TrainingProgram(
                            name: name.isEmpty ? "Custom Program" : name,
                            distance: distance,
                            runInterval: runInterval,
                            walkInterval: walkInterval,
                            totalDuration: totalDuration,
                            difficulty: difficulty,
                            description: description,
                            estimatedCalories: estimatedCalories,
                            targetHeartRateZone: targetHeartRateZone,
                            isCustom: true
                        )
                        onSave(program)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Program Detail View

struct ProgramDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var program: TrainingProgram
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    
    let isCustom: Bool
    let onUpdate: (TrainingProgram) -> Void
    let onDelete: () -> Void
    
    init(program: TrainingProgram, isCustom: Bool, onUpdate: @escaping (TrainingProgram) -> Void, onDelete: @escaping () -> Void) {
        _program = State(initialValue: program)
        self.isCustom = isCustom
        self.onUpdate = onUpdate
        self.onDelete = onDelete
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(program.name)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            DifficultyBadge(difficulty: program.difficulty)
                        }
                        
                        if !program.description.isEmpty {
                            Text(program.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Stats
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        StatCard(icon: "location", title: "Distance", value: program.formattedDistance, color: .blue)
                        StatCard(icon: "clock", title: "Duration", value: program.formattedDuration, color: .green)
                        StatCard(icon: "figure.run", title: "Run", value: "\(String(format: "%.1f", program.runInterval)) min", color: .red)
                        StatCard(icon: "figure.walk", title: "Walk", value: "\(String(format: "%.1f", program.walkInterval)) min", color: .orange)
                        StatCard(icon: "flame", title: "Calories", value: "\(program.estimatedCalories)", color: .purple)
                        StatCard(icon: "heart", title: "HR Zone", value: program.targetHeartRateZone.rawValue.capitalized, color: program.targetHeartRateZone.color)
                    }
                    
                    // Training Note
                    VStack(spacing: 8) {
                        Text("Training Available on Apple Watch")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("Use your Apple Watch to start this workout")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Program Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if isCustom {
                            Button("Edit") {
                                isEditing = true
                            }
                            
                            Button("Delete") {
                                showingDeleteAlert = true
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditProgramView(program: program) { updatedProgram in
                program = updatedProgram
                onUpdate(updatedProgram)
            }
        }
        .alert("Delete Program", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete '\(program.name)'? This action cannot be undone.")
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Edit Program View

struct EditProgramView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var program: TrainingProgram
    
    let onSave: (TrainingProgram) -> Void
    
    init(program: TrainingProgram, onSave: @escaping (TrainingProgram) -> Void) {
        _program = State(initialValue: program)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Program Name", text: $program.name)
                    TextField("Description", text: $program.description, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Intervals") {
                    HStack {
                        Text("Run Interval")
                        Spacer()
                        Text("\(String(format: "%.1f", program.runInterval)) min")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $program.runInterval, in: 0.5...10.0, step: 0.5)
                    
                    HStack {
                        Text("Walk Interval")
                        Spacer()
                        Text("\(String(format: "%.1f", program.walkInterval)) min")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $program.walkInterval, in: 0.5...5.0, step: 0.5)
                }
                
                Section("Workout Details") {
                    HStack {
                        Text("Total Duration")
                        Spacer()
                        Text("\(Int(program.totalDuration)) min")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $program.totalDuration, in: 10...120, step: 5)
                    
                    HStack {
                        Text("Distance")
                        Spacer()
                        Text("\(String(format: "%.1f", program.distance)) km")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $program.distance, in: 1.0...20.0, step: 0.5)
                    
                    HStack {
                        Text("Estimated Calories")
                        Spacer()
                        Text("\(program.estimatedCalories)")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(program.estimatedCalories) },
                        set: { program.estimatedCalories = Int($0) }
                    ), in: 100...1000, step: 25)
                }
                
                Section("Difficulty & Target") {
                    Picker("Difficulty", selection: $program.difficulty) {
                        ForEach(TrainingDifficulty.allCases, id: \.self) { level in
                            Text(level.rawValue.capitalized).tag(level)
                        }
                    }
                    
                    Picker("Heart Rate Zone", selection: $program.targetHeartRateZone) {
                        ForEach(HeartRateZone.allCases, id: \.self) { zone in
                            Text(zone.rawValue.capitalized).tag(zone)
                        }
                    }
                }
            }
            .navigationTitle("Edit Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(program)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Default Programs

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
        targetHeartRateZone: .zone2
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
        targetHeartRateZone: .zone4
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
        targetHeartRateZone: .zone3
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
        targetHeartRateZone: .zone5
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
        targetHeartRateZone: .zone1
    )
]

#Preview {
    ProgramsView()
        .environmentObject(ServiceLocator.shared)
}
