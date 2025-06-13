//
//  WorkoutDashboardView.swift
//  ShuttlX MVP
//
//  Enhanced with performance monitoring and optimization
//  Created by ShuttlX on 6/8/25.
//

import SwiftUI
import HealthKit

struct WorkoutDashboardView: View {
    @EnvironmentObject private var serviceLocator: ServiceLocator
    @StateObject private var performanceService = PerformanceOptimizationService.shared
    @StateObject private var performanceMonitor = AdvancedPerformanceMonitor.shared
    @State private var showingWorkoutSelection = false
    @State private var showingPerformanceMonitor = false
    @State private var selectedProgram: TrainingProgram?
    
    var body: some View {
        NavigationView {
            OptimizedScrollView {
                VStack(spacing: 20) {
                    // Performance indicator and monitoring access
                    performanceHeaderSection
                    
                    // Enhanced today's summary with performance optimization
                    EnhancedTodaySummaryCard()
                        .optimizedForLists()
                    
                    // Quick Start Section
                    quickStartSection
                        .optimizedForLists()
                    
                    // Training Programs Preview
                    trainingProgramsPreview
                        .optimizedForLists()
                    
                    // Recent Activity with optimized loading
                    if !serviceLocator.healthManager.recentWorkouts.isEmpty {
                        recentActivitySection
                            .optimizedForLists()
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Workouts")
            .onOptimizedAppear {
                loadDashboardData()
            }
            .sheet(isPresented: $showingWorkoutSelection) {
                WorkoutSelectionView()
            }
            .sheet(item: $selectedProgram) { program in
                TrainingProgramDetailView(program: program)
            }
            .sheet(isPresented: $showingPerformanceMonitor) {
                PerformanceMonitoringDashboard()
            }
        }
    }
    
    // MARK: - Performance Header Section
    private var performanceHeaderSection: some View {
        VStack(spacing: 12) {
            // Performance indicator (when memory usage is high)
            if performanceService.memoryUsage != .normal {
                PerformanceIndicatorView()
            }
            
            // Performance monitoring access button
            HStack {
                Spacer()
                Button(action: {
                    showingPerformanceMonitor = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "speedometer")
                            .font(.caption)
                        Text("Performance")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
            }
        }
    }
    
    // MARK: - Quick Start Section
    private var quickStartSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Start")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                QuickStartButton(
                    title: "5K Training",
                    subtitle: "Beginner friendly",
                    icon: "figure.run",
                    color: .blue
                ) {
                    // Start 5K program
                }
                
                QuickStartButton(
                    title: "HIIT Workout",
                    subtitle: "High intensity",
                    icon: "bolt.fill",
                    color: .orange
                ) {
                    // Start HIIT program
                }
                
                QuickStartButton(
                    title: "Custom Run",
                    subtitle: "Your intervals",
                    icon: "slider.horizontal.3",
                    color: .purple
                ) {
                    showingWorkoutSelection = true
                }
                
                QuickStartButton(
                    title: "Recovery",
                    subtitle: "Active rest",
                    icon: "leaf.fill",
                    color: .green
                ) {
                    // Start recovery program
                }
            }
        }
    }
    
    // MARK: - Training Programs Preview
    private var trainingProgramsPreview: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recommended Programs")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                NavigationLink("See All") {
                    ProgramsView()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            // Use optimized loading for featured programs
            let featuredPrograms = performanceService.loadDataWithPagination(
                data: TrainingProgramManager.shared.defaultPrograms,
                pageSize: 3
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(featuredPrograms) { program in
                        ProgramPreviewCard(program: program) {
                            selectedProgram = program
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Recent Activity Section
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("View All") {
                    // Navigate to full history
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            LazyVStack(spacing: 8) {
                // Use optimized list for recent workouts
                let recentWorkouts = performanceService.loadDataWithPagination(
                    data: serviceLocator.healthManager.recentWorkouts,
                    pageSize: 5
                )
                
                ForEach(recentWorkouts.prefix(3), id: \.uuid) { workout in
                    EnhancedWorkoutRow(workout: workout)
                        .optimizedForLists()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private func loadDashboardData() {
        // Use debounced loading to prevent excessive calls
        performanceService.debounceViewUpdate(
            for: performanceService,
            delay: 0.2
        ) {
            // Load health data and refresh UI
            serviceLocator.healthManager.fetchTodayData()
        }
    }
}

// MARK: - Performance Monitoring Dashboard
struct PerformanceMonitoringDashboard: View {
    @StateObject private var performanceMonitor = AdvancedPerformanceMonitor.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Current Performance Metrics
                    currentMetricsSection
                    
                    // Performance Alerts
                    performanceAlertsSection
                    
                    // Optimization Suggestions
                    optimizationSuggestionsSection
                    
                    // Resource Usage History
                    resourceUsageHistorySection
                }
                .padding()
            }
            .navigationTitle("Performance Monitor")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var currentMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Performance")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                PerformanceMetricCard(
                    title: "Memory Usage",
                    value: performanceMonitor.currentMetrics.memoryUsageMB,
                    unit: "MB",
                    status: getMemoryStatus(performanceMonitor.currentMetrics.memoryUsageMB),
                    icon: "memorychip"
                )
                
                PerformanceMetricCard(
                    title: "CPU Usage",
                    value: performanceMonitor.currentMetrics.cpuUsage,
                    unit: "%",
                    status: getCPUStatus(performanceMonitor.currentMetrics.cpuUsage),
                    icon: "cpu"
                )
                
                PerformanceMetricCard(
                    title: "Active Timers",
                    value: Double(performanceMonitor.currentMetrics.activeTimers),
                    unit: "",
                    status: getTimerStatus(performanceMonitor.currentMetrics.activeTimers),
                    icon: "timer"
                )
                
                PerformanceMetricCard(
                    title: "Battery",
                    value: Double(performanceMonitor.currentMetrics.batteryLevel) * 100,
                    unit: "%",
                    status: getBatteryStatus(performanceMonitor.currentMetrics.batteryLevel),
                    icon: "battery.100"
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private var performanceAlertsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Alerts")
                .font(.headline)
                .fontWeight(.semibold)
            
            if performanceMonitor.alerts.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All systems running optimally")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(performanceMonitor.alerts) { alert in
                        PerformanceAlertRow(alert: alert.message)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private var optimizationSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Optimization Suggestions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 12) {
                ForEach(performanceMonitor.optimizationSuggestions) { suggestion in
                    OptimizationSuggestionRow(suggestion: suggestion.description)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private var resourceUsageHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Resource Usage Trends")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Simple chart representation
            VStack(spacing: 12) {
                HStack {
                    Text("Memory")
                        .font(.subheadline)
                    Spacer()
                    Text("Stable")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                ProgressView(value: performanceMonitor.currentMetrics.memoryUsageMB / 1024, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                
                HStack {
                    Text("CPU")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(performanceMonitor.currentMetrics.cpuUsage))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: performanceMonitor.currentMetrics.cpuUsage / 100, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .orange))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    // MARK: - Helper Functions
    private func getMemoryStatus(_ memoryUsage: Double) -> PerformanceStatus {
        if memoryUsage > 200 {
            return .critical
        } else if memoryUsage > 150 {
            return .warning
        } else {
            return .optimal
        }
    }
    
    private func getCPUStatus(_ cpuUsage: Double) -> PerformanceStatus {
        if cpuUsage > 85 {
            return .critical
        } else if cpuUsage > 70 {
            return .warning
        } else {
            return .optimal
        }
    }
    
    private func getTimerStatus(_ timerCount: Int) -> PerformanceStatus {
        if timerCount > 15 {
            return .critical
        } else if timerCount > 10 {
            return .warning
        } else {
            return .optimal
        }
    }
    
    private func getBatteryStatus(_ batteryLevel: Float) -> PerformanceStatus {
        if batteryLevel < 0.15 {
            return .critical
        } else if batteryLevel < 0.30 {
            return .warning
        } else {
            return .optimal
        }
    }
}

// MARK: - Supporting Views for Performance Dashboard

struct PerformanceMetricCard: View {
    let title: String
    let value: Double
    let unit: String
    let status: PerformanceStatus
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(status.color)
                Spacer()
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(formatValue(value))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(status.color.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func formatValue(_ value: Double) -> String {
        if unit.isEmpty {
            return "\(Int(value))"
        } else {
            return String(format: "%.1f", value)
        }
    }
}

struct PerformanceAlertRow: View {
    let alert: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(alert)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

struct OptimizationSuggestionRow: View {
    let suggestion: String
    
    var body: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.blue)
            Text(suggestion)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Enhanced Supporting Views

struct EnhancedTodaySummaryCard: View {
    @EnvironmentObject var serviceLocator: ServiceLocator
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Activity")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { 
                    withAnimation(.spring()) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            // Main metrics
            HStack(spacing: 20) {
                EnhancedSummaryMetric(
                    title: "Steps",
                    value: "\(Int(serviceLocator.healthManager.todaySteps))",
                    icon: "figure.walk",
                    color: .blue,
                    target: "10,000"
                )
                
                EnhancedSummaryMetric(
                    title: "Calories",
                    value: "\(Int(serviceLocator.healthManager.todayCalories))",
                    icon: "flame.fill",
                    color: .orange,
                    target: "500"
                )
                
                EnhancedSummaryMetric(
                    title: "Heart Rate",
                    value: serviceLocator.healthManager.currentHeartRate > 0 ? 
                        "\(Int(serviceLocator.healthManager.currentHeartRate))" : "--",
                    icon: "heart.fill",
                    color: .red,
                    target: "70"
                )
            }
            
            // Expanded details
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                    
                    HStack {
                        Text("Weekly Goal Progress")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("65%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    ProgressView(value: 0.65)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("This Week")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("3 workouts")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Streak")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("5 days")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    }
                }
                .optimizedAnimation(.easeInOut(duration: 0.3), value: isExpanded)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct EnhancedSummaryMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let target: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("/ \(target)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickStartButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(color.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProgramPreviewCard: View {
    let program: TrainingProgram
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(program.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(program.difficulty.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(program.difficulty.color)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(program.totalDuration)) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Image(systemName: "flame")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("\(program.estimatedCalories)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !program.description.isEmpty {
                        Text(program.description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .padding()
            .frame(width: 240)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EnhancedWorkoutRow: View {
    let workout: HKWorkout
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.workoutActivityType.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(workout.startDate.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDuration(workout.duration))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let statistics = workout.statistics(for: HKQuantityType(.activeEnergyBurned)),
                   let calories = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                    Text("\(Int(calories)) cal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - HKWorkoutActivityType Extension
extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .mixedCardio: return "Mixed Cardio"
        default: return "Workout"
        }
    }
}
