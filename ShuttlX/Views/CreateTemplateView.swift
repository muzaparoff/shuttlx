//
//  CreateTemplateView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct CreateTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateTemplateViewModel()
    let onSave: (WorkoutTemplate) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information
                Section("Template Information") {
                    TextField("Template Name", text: $viewModel.templateName)
                    
                    Picker("Workout Type", selection: $viewModel.selectedType) {
                        ForEach(WorkoutType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    Picker("Difficulty", selection: $viewModel.selectedDifficulty) {
                        ForEach(DifficultyLevel.allCases, id: \.self) { difficulty in
                            Text(difficulty.rawValue.capitalized).tag(difficulty)
                        }
                    }
                }
                
                // Description and Notes
                Section("Description") {
                    TextField("Template description...", text: $viewModel.templateNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // Tags
                Section("Tags") {
                    TextField("Add tags (comma separated)", text: $viewModel.tagsText)
                    
                    if !viewModel.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(viewModel.tags, id: \.self) { tag in
                                    TagChip(tag: tag) {
                                        viewModel.removeTag(tag)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Quick Setup Options
                Section("Quick Setup") {
                    Button("Shuttle Run Template") {
                        viewModel.loadShuttleRunTemplate()
                    }
                    
                    Button("HIIT Template") {
                        viewModel.loadHIITTemplate()
                    }
                    
                    Button("Interval Template") {
                        viewModel.loadIntervalTemplate()
                    }
                    
                    Button("Custom Template") {
                        viewModel.loadCustomTemplate()
                    }
                }
                
                // Intervals Preview
                if !viewModel.intervals.isEmpty {
                    Section("Intervals Preview") {
                        ForEach(Array(viewModel.intervals.enumerated()), id: \.offset) { index, interval in
                            IntervalPreviewRow(interval: interval, index: index)
                        }
                        
                        Button("Customize Intervals") {
                            viewModel.showIntervalBuilder = true
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                // Template Summary
                if viewModel.isValidTemplate {
                    Section("Template Summary") {
                        HStack {
                            Text("Total Duration")
                            Spacer()
                            Text(formatDuration(viewModel.totalDuration))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Total Intervals")
                            Spacer()
                            Text("\(viewModel.intervals.count)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Est. Calories")
                            Spacer()
                            Text("\(viewModel.estimatedCalories)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Create Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let template = viewModel.createTemplate()
                        onSave(template)
                        dismiss()
                    }
                    .disabled(!viewModel.isValidTemplate)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $viewModel.showIntervalBuilder) {
                // This would open a more detailed interval builder
                IntervalBuilderView(intervals: $viewModel.intervals)
            }
        }
    }
}

// MARK: - Supporting Views

struct TagChip: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(12)
    }
}

struct IntervalPreviewRow: View {
    let interval: WorkoutInterval
    let index: Int
    
    var body: some View {
        HStack {
            Text("\(index + 1).")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .leading)
            
            Image(systemName: interval.type.icon)
                .foregroundColor(interval.intensity.color)
                .frame(width: 20)
            
            Text(interval.type.displayName)
                .font(.subheadline)
            
            Spacer()
            
            Text(interval.durationText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct IntervalBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var intervals: [WorkoutInterval]
    @State private var editingIntervals: [WorkoutInterval] = []
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(editingIntervals.enumerated()), id: \.offset) { index, interval in
                    IntervalBuilderRow(
                        interval: interval,
                        index: index,
                        onUpdate: { updatedInterval in
                            editingIntervals[index] = updatedInterval
                        },
                        onDelete: {
                            editingIntervals.remove(at: index)
                        }
                    )
                }
                .onMove(perform: moveIntervals)
                
                Button("Add Interval") {
                    editingIntervals.append(WorkoutInterval(
                        type: .work,
                        duration: 30,
                        intensity: .moderate,
                        distance: nil,
                        notes: ""
                    ))
                }
                .foregroundColor(.blue)
            }
            .navigationTitle("Build Intervals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        intervals = editingIntervals
                        dismiss()
                    }
                }
            }
            .onAppear {
                editingIntervals = intervals
            }
        }
    }
    
    private func moveIntervals(from source: IndexSet, to destination: Int) {
        editingIntervals.move(fromOffsets: source, toOffset: destination)
    }
}

struct IntervalBuilderRow: View {
    let interval: WorkoutInterval
    let index: Int
    let onUpdate: (WorkoutInterval) -> Void
    let onDelete: () -> Void
    
    @State private var showingEdit = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(index + 1). \(interval.type.displayName)")
                    .font(.headline)
                
                Text("\(interval.durationText) • \(interval.intensity.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !interval.notes.isEmpty {
                    Text(interval.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Button("Edit") {
                showingEdit = true
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
        .sheet(isPresented: $showingEdit) {
            IntervalEditView(interval: interval) { updatedInterval in
                onUpdate(updatedInterval)
                showingEdit = false
            }
        }
    }
}

// MARK: - Helper Functions

private func formatDuration(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    
    if minutes > 0 {
        return "\(minutes):\(String(format: "%02d", seconds))"
    } else {
        return "\(seconds)s"
    }
}

#Preview {
    CreateTemplateView { template in
        print("Created template: \(template.name)")
    }
}
