//
//  IntervalEditView.swift
//  ShuttlX
//
//  Enhanced comprehensive interval editing interface with advanced features
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct IntervalEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var editedInterval: WorkoutInterval
    @State private var showingAdvancedOptions = false
    @State private var showingPresets = false
    @State private var customDurationMinutes = 0
    @State private var customDurationSeconds = 0
    @State private var targetHeartRateMin = 120
    @State private var targetHeartRateMax = 160
    @State private var showingTargetZoneInfo = false
    @State private var selectedPreset: IntervalPreset?
    
    let onSave: (WorkoutInterval) -> Void
    let isNewInterval: Bool
    
    init(interval: WorkoutInterval? = nil, onSave: @escaping (WorkoutInterval) -> Void) {
        if let interval = interval {
            self._editedInterval = State(initialValue: interval)
            self.isNewInterval = false
        } else {
            self._editedInterval = State(initialValue: WorkoutInterval(
                type: .work,
                duration: 30,
                intensity: .moderate,
                distance: nil,
                notes: ""
            ))
            self.isNewInterval = true
        }
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Interval Type Card
                    intervalTypeCard
                    
                    // Duration Configuration
                    durationConfigCard
                    
                    // Intensity Configuration
                    intensityConfigCard
                    
                    // Distance Configuration (for shuttle runs)
                    if shouldShowDistanceConfig {
                        distanceConfigCard
                    }
                    
                    // Target Heart Rate Zone
                    heartRateZoneCard
                    
                    // Notes and Instructions
                    notesCard
                    
                    // Advanced Options
                    if showingAdvancedOptions {
                        advancedOptionsCard
                    }
                    
                    // Preset Quick Actions
                    presetsCard
                    
                    // Action Buttons
                    actionButtonsCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isNewInterval ? "Add Interval" : "Edit Interval")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveInterval()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValidInterval)
                }
            }
            .sheet(isPresented: $showingPresets) {
                IntervalPresetsView { preset in
                    applyPreset(preset)
                    showingPresets = false
                }
            }
            .sheet(isPresented: $showingTargetZoneInfo) {
                HeartRateZoneInfoView()
            }
        }
    }
    
    // MARK: - Interval Type Card
    private var intervalTypeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeader(title: "Interval Type", icon: "timer", color: .blue)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(IntervalType.allCases, id: \.self) { type in
                    IntervalTypeButton(
                        type: type,
                        isSelected: editedInterval.type == type
                    ) {
                        editedInterval.type = type
                        updateDefaultsForType(type)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Duration Configuration Card
    private var durationConfigCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeader(title: "Duration", icon: "clock", color: .orange)
            
            VStack(spacing: 16) {
                // Duration Picker
                HStack {
                    Text("Duration")
                        .font(.headline)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Picker("Minutes", selection: $customDurationMinutes) {
                            ForEach(0...59, id: \.self) { minute in
                                Text("\(minute)m").tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 100)
                        .clipped()
                        
                        Picker("Seconds", selection: $customDurationSeconds) {
                            ForEach(0...59, id: \.self) { second in
                                Text("\(second)s").tag(second)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 100)
                        .clipped()
                    }
                }
                
                // Quick Duration Buttons
                quickDurationButtons
                
                // Duration Preview
                durationPreview
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onAppear {
            updateDurationPickers()
        }
        .onChange(of: customDurationMinutes) { _, _ in updateDurationFromPickers() }
        .onChange(of: customDurationSeconds) { _, _ in updateDurationFromPickers() }
    }
    
    // MARK: - Quick Duration Buttons
    private var quickDurationButtons: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Select")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(quickDurationOptions, id: \.self) { duration in
                    Button(action: {
                        editedInterval.duration = TimeInterval(duration)
                        updateDurationPickers()
                    }) {
                        Text(formatDuration(duration))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(editedInterval.duration == TimeInterval(duration) ? .white : .blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(editedInterval.duration == TimeInterval(duration) ? Color.blue : Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    // MARK: - Duration Preview
    private var durationPreview: some View {
        HStack {
            Image(systemName: "clock.circle.fill")
                .foregroundColor(.orange)
            
            Text("Total: \(formatDuration(Int(editedInterval.duration)))")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Text(intensityTimeRecommendation)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Intensity Configuration Card
    private var intensityConfigCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeader(title: "Intensity Level", icon: "flame", color: .red)
            
            VStack(spacing: 16) {
                // Intensity Selector
                VStack(spacing: 12) {
                    ForEach(Intensity.allCases, id: \.self) { intensity in
                        IntensityButton(
                            intensity: intensity,
                            isSelected: editedInterval.intensity == intensity
                        ) {
                            editedInterval.intensity = intensity
                            updateTargetHeartRateForIntensity(intensity)
                        }
                    }
                }
                
                // Intensity Description
                intensityDescription
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Distance Configuration Card
    private var distanceConfigCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeader(title: "Shuttle Distance", icon: "arrow.left.arrow.right", color: .green)
            
            VStack(spacing: 16) {
                // Distance Input
                HStack {
                    Text("Distance")
                        .font(.headline)
                    
                    Spacer()
                    
                    HStack {
                        TextField("Distance", value: Binding(
                            get: { editedInterval.distance ?? 20 },
                            set: { editedInterval.distance = $0 }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        
                        Text("meters")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Common Distance Presets
                commonDistancePresets
                
                // Distance Visualization
                distanceVisualization
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Heart Rate Zone Card
    private var heartRateZoneCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                CardHeader(title: "Target Heart Rate Zone", icon: "heart", color: .pink)
                
                Spacer()
                
                Button(action: { showingTargetZoneInfo = true }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
            }
            
            VStack(spacing: 16) {
                // Heart Rate Range
                VStack(spacing: 12) {
                    HStack {
                        Text("Target Range")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("\(targetHeartRateMin) - \(targetHeartRateMax) BPM")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.pink)
                    }
                    
                    // Range Sliders
                    VStack(spacing: 8) {
                        HStack {
                            Text("Min")
                                .font(.caption)
                                .frame(width: 30)
                            
                            Slider(value: Binding(
                                get: { Double(targetHeartRateMin) },
                                set: { targetHeartRateMin = Int($0) }
                            ), in: 60...200, step: 1)
                            
                            Text("\(targetHeartRateMin)")
                                .font(.caption)
                                .frame(width: 35)
                        }
                        
                        HStack {
                            Text("Max")
                                .font(.caption)
                                .frame(width: 30)
                            
                            Slider(value: Binding(
                                get: { Double(targetHeartRateMax) },
                                set: { targetHeartRateMax = Int($0) }
                            ), in: 60...200, step: 1)
                            
                            Text("\(targetHeartRateMax)")
                                .font(.caption)
                                .frame(width: 35)
                        }
                    }
                }
                
                // Heart Rate Zone Indicator
                heartRateZoneIndicator
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Notes Card
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeader(title: "Instructions & Notes", icon: "note.text", color: .purple)
            
            VStack(spacing: 12) {
                TextEditor(text: $editedInterval.notes)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                // Suggested Notes
                if !suggestedNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggestions")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(suggestedNotes, id: \.self) { note in
                                Button(action: {
                                    if editedInterval.notes.isEmpty {
                                        editedInterval.notes = note
                                    } else {
                                        editedInterval.notes += "\n\(note)"
                                    }
                                }) {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
                                
                                Text("meters")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Toggle("Time-based instead", isOn: Binding(
                            get: { editedInterval.distance == nil },
                            set: { isTimeBased in
                                if isTimeBased {
                                    editedInterval.distance = nil
                                } else {
                                    editedInterval.distance = 20
                                }
                            }
                        ))
                    } else {
                        // Time-based interval
                        DurationPicker(duration: $editedInterval.duration)
                        
                        Toggle("Distance-based instead", isOn: Binding(
                            get: { editedInterval.distance != nil },
                            set: { isDistanceBased in
                                if isDistanceBased {
                                    editedInterval.distance = 20
                                } else {
                                    editedInterval.distance = nil
                                }
                            }
                        ))
                    }
                }
                
                // Intensity Section
                Section("Intensity") {
                    Picker("Intensity", selection: $editedInterval.intensity) {
                        ForEach(ExerciseIntensity.allCases, id: \.self) { intensity in
                            HStack {
                                Circle()
                                    .fill(intensity.color)
                                    .frame(width: 12, height: 12)
                                Text(intensity.displayName)
                            }
                            .tag(intensity)
                        }
                    }
                    .pickerStyle(.automatic)
                }
                
                // Notes Section
                Section("Notes") {
                    TextField("Add notes or instructions...", text: $editedInterval.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // Preview Section
                Section("Preview") {
                    IntervalPreviewCard(interval: editedInterval)
                }
            }
            .navigationTitle("Edit Interval")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(editedInterval)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct DurationPicker: View {
    @Binding var duration: TimeInterval
    
    private var minutes: Int {
        Int(duration) / 60
    }
    
    private var seconds: Int {
        Int(duration) % 60
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Duration")
                .font(.headline)
            
            HStack {
                // Minutes
                VStack {
                    Text("Minutes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Minutes", selection: Binding(
                        get: { minutes },
                        set: { duration = TimeInterval($0 * 60 + seconds) }
                    )) {
                        ForEach(0..<60, id: \.self) { minute in
                            Text("\(minute)").tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 120)
                }
                
                Text(":")
                    .font(.title)
                    .fontWeight(.bold)
                
                // Seconds
                VStack {
                    Text("Seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Seconds", selection: Binding(
                        get: { seconds },
                        set: { duration = TimeInterval(minutes * 60 + $0) }
                    )) {
                        ForEach(0..<60, id: \.self) { second in
                            Text(String(format: "%02d", second)).tag(second)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 120)
                }
            }
            
            // Quick duration buttons
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach([10, 15, 20, 30, 45, 60, 90, 120], id: \.self) { seconds in
                    Button(action: { duration = TimeInterval(seconds) }) {
                        Text("\(seconds)s")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(duration == TimeInterval(seconds) ? Color.blue : Color(.systemGray6))
                            .foregroundColor(duration == TimeInterval(seconds) ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
        }
    }
}

struct IntervalPreviewCard: View {
    let interval: WorkoutInterval
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: interval.type.icon)
                    .foregroundColor(interval.intensity.color)
                
                Text(interval.type.displayName)
                    .font(.headline)
                    .foregroundColor(interval.intensity.color)
                
                Spacer()
                
                Text(interval.durationText)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("Intensity:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Circle()
                    .fill(interval.intensity.color)
                    .frame(width: 8, height: 8)
                
                Text(interval.intensity.displayName)
                    .font(.caption)
                    .foregroundColor(interval.intensity.color)
                
                Spacer()
            }
            
            if !interval.notes.isEmpty {
                Text(interval.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    IntervalEditView(
        interval: WorkoutInterval(
            type: .work,
            duration: 30,
            intensity: .high,
            distance: nil,
            notes: "Sample interval"
        )
    ) { _ in }
}
