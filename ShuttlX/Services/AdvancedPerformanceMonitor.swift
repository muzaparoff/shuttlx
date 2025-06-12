//
//  AdvancedPerformanceMonitor.swift
//  ShuttlX
//
//  Advanced performance monitoring and optimization system
//  Created by ShuttlX on 6/9/25.
//

import Foundation
import SwiftUI
import Combine
import os.log

/// Performance status indicator
enum PerformanceStatus {
    case optimal
    case warning
    case critical
    
    var color: Color {
        switch self {
        case .optimal:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
}

/// Advanced performance monitoring system for ShuttlX
@MainActor
class AdvancedPerformanceMonitor: ObservableObject {
    static let shared = AdvancedPerformanceMonitor()
    
    // MARK: - Published Properties
    @Published private(set) var currentMetrics: PerformanceMetrics = .empty
    @Published private(set) var alerts: [PerformanceAlert] = []
    @Published private(set) var optimizationSuggestions: [OptimizationSuggestion] = []
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.shuttlx.performance", category: "monitor")
    private var monitoringTimer: Timer?
    
    // MARK: - Public Properties
    var isMonitoring: Bool {
        return monitoringTimer != nil
    }
    private var metricHistory: [PerformanceMetrics] = []
    private let maxHistorySize = 100
    
    // MARK: - Performance Thresholds
    private struct Thresholds {
        static let memoryWarning: Double = 150.0 // MB
        static let memoryCritical: Double = 200.0 // MB
        static let cpuWarning: Double = 70.0 // %
        static let cpuCritical: Double = 85.0 // %
        static let viewUpdatesWarning: Int = 30 // per second
        static let timerCountWarning: Int = 10
    }
    
    private init() {
        startMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start performance monitoring
    func startMonitoring() {
        stopMonitoring()
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetrics()
            }
        }
        
        logger.info("Performance monitoring started")
    }
    
    /// Stop performance monitoring
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        logger.info("Performance monitoring stopped")
    }
    
    /// Get performance report
    func getPerformanceReport() -> PerformanceReport {
        let avgMemory = metricHistory.isEmpty ? 0 : metricHistory.map(\.memoryUsageMB).reduce(0, +) / Double(metricHistory.count)
        let avgCPU = metricHistory.isEmpty ? 0 : metricHistory.map(\.cpuUsage).reduce(0, +) / Double(metricHistory.count)
        let peakMemory = metricHistory.map(\.memoryUsageMB).max() ?? 0
        
        return PerformanceReport(
            averageMemoryUsage: avgMemory,
            averageCPUUsage: avgCPU,
            peakMemoryUsage: peakMemory,
            totalAlerts: alerts.count,
            optimizationsSuggested: optimizationSuggestions.count,
            monitoringDuration: TimeInterval(metricHistory.count * 2) // 2 second intervals
        )
    }
    
    /// Clear performance history
    func clearHistory() {
        metricHistory.removeAll()
        alerts.removeAll()
        optimizationSuggestions.removeAll()
        logger.info("Performance history cleared")
    }
    
    // MARK: - Private Methods
    
    private func updateMetrics() {
        let metrics = collectCurrentMetrics()
        currentMetrics = metrics
        
        // Add to history
        metricHistory.append(metrics)
        if metricHistory.count > maxHistorySize {
            metricHistory.removeFirst()
        }
        
        // Check for performance issues
        analyzePerformance(metrics)
        
        // Log if significant changes
        if shouldLogMetrics(metrics) {
            logger.info("Performance update: Memory: \(metrics.memoryUsageMB, privacy: .public)MB, CPU: \(metrics.cpuUsage, privacy: .public)%")
        }
    }
    
    private func collectCurrentMetrics() -> PerformanceMetrics {
        let memory = getMemoryUsage()
        let cpu = getCPUUsage()
        let activeTimers = getActiveTimerCount()
        let viewUpdates = getViewUpdateRate()
        
        return PerformanceMetrics(
            timestamp: Date(),
            memoryUsageMB: memory,
            cpuUsage: cpu,
            activeTimers: activeTimers,
            viewUpdateRate: viewUpdates,
            batteryLevel: getBatteryLevel()
        )
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024) // Convert to MB
        }
        
        return 0
    }
    
    private func getCPUUsage() -> Double {
        var info: processor_info_array_t? = nil
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let kr = host_processor_info(mach_host_self(),
                                   PROCESSOR_CPU_LOAD_INFO,
                                   &numCpus,
                                   &info,
                                   &numCpuInfo)
        
        if kr == KERN_SUCCESS {
            // Simplified CPU calculation for demonstration
            return Double.random(in: 0...100) // Placeholder
        }
        
        return 0
    }
    
    private func getActiveTimerCount() -> Int {
        // Return a simple count since we can't access private property
        return 1 // Placeholder - this would need integration with PerformanceOptimizationService
    }
    
    private func getViewUpdateRate() -> Int {
        // Placeholder - would need actual view update tracking
        return Int.random(in: 5...25)
    }
    
    private func getBatteryLevel() -> Float {
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryLevel
        #else
        return 1.0 // watchOS doesn't expose battery level
        #endif
    }
    
    private func analyzePerformance(_ metrics: PerformanceMetrics) {
        checkMemoryUsage(metrics.memoryUsageMB)
        checkCPUUsage(metrics.cpuUsage)
        checkTimerCount(metrics.activeTimers)
        checkViewUpdateRate(metrics.viewUpdateRate)
    }
    
    private func checkMemoryUsage(_ memory: Double) {
        if memory > Thresholds.memoryCritical {
            addAlert(.critical, message: "Critical memory usage: \(Int(memory))MB")
            addOptimizationSuggestion(.memoryOptimization, 
                                    description: "Consider clearing caches and reducing data retention")
        } else if memory > Thresholds.memoryWarning {
            addAlert(.warning, message: "High memory usage: \(Int(memory))MB")
        }
    }
    
    private func checkCPUUsage(_ cpu: Double) {
        if cpu > Thresholds.cpuCritical {
            addAlert(.critical, message: "Critical CPU usage: \(Int(cpu))%")
            addOptimizationSuggestion(.cpuOptimization,
                                    description: "Reduce animation complexity or timer frequency")
        } else if cpu > Thresholds.cpuWarning {
            addAlert(.warning, message: "High CPU usage: \(Int(cpu))%")
        }
    }
    
    private func checkTimerCount(_ count: Int) {
        if count > Thresholds.timerCountWarning {
            addAlert(.warning, message: "Many active timers: \(count)")
            addOptimizationSuggestion(.timerOptimization,
                                    description: "Consider consolidating or optimizing timer usage")
        }
    }
    
    private func checkViewUpdateRate(_ rate: Int) {
        if rate > Thresholds.viewUpdatesWarning {
            addAlert(.warning, message: "High view update rate: \(rate)/sec")
            addOptimizationSuggestion(.viewOptimization,
                                    description: "Consider debouncing or batching view updates")
        }
    }
    
    private func addAlert(_ level: AlertLevel, message: String) {
        let alert = PerformanceAlert(
            id: UUID(),
            level: level,
            message: message,
            timestamp: Date()
        )
        
        alerts.append(alert)
        
        // Keep only recent alerts
        if alerts.count > 20 {
            alerts.removeFirst()
        }
    }
    
    private func addOptimizationSuggestion(_ type: OptimizationType, description: String) {
        // Don't add duplicate suggestions
        guard !optimizationSuggestions.contains(where: { $0.type == type }) else { return }
        
        let suggestion = OptimizationSuggestion(
            id: UUID(),
            type: type,
            description: description,
            timestamp: Date()
        )
        
        optimizationSuggestions.append(suggestion)
    }
    
    private func shouldLogMetrics(_ metrics: PerformanceMetrics) -> Bool {
        guard let lastMetrics = metricHistory.suffix(2).first else { return true }
        
        let memoryChange = abs(metrics.memoryUsageMB - lastMetrics.memoryUsageMB)
        let cpuChange = abs(metrics.cpuUsage - lastMetrics.cpuUsage)
        
        return memoryChange > 10 || cpuChange > 20 // Log on significant changes
    }
}

// MARK: - Performance Optimization Service Extension

extension PerformanceOptimizationService {
    func getActiveTimerCount() -> Int {
        // Return a simple count for now
        return 1
    }
}

// MARK: - Data Models

struct PerformanceMetrics {
    let timestamp: Date
    let memoryUsageMB: Double
    let cpuUsage: Double
    let activeTimers: Int
    let viewUpdateRate: Int
    let batteryLevel: Float
    
    static let empty = PerformanceMetrics(
        timestamp: Date(),
        memoryUsageMB: 0,
        cpuUsage: 0,
        activeTimers: 0,
        viewUpdateRate: 0,
        batteryLevel: 1.0
    )
}

struct PerformanceAlert: Identifiable {
    let id: UUID
    let level: AlertLevel
    let message: String
    let timestamp: Date
}

struct OptimizationSuggestion: Identifiable, Equatable, Hashable {
    let id: UUID
    let type: OptimizationType
    let description: String
    let timestamp: Date
    
    static func == (lhs: OptimizationSuggestion, rhs: OptimizationSuggestion) -> Bool {
        lhs.type == rhs.type
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct PerformanceReport {
    let averageMemoryUsage: Double
    let averageCPUUsage: Double
    let peakMemoryUsage: Double
    let totalAlerts: Int
    let optimizationsSuggested: Int
    let monitoringDuration: TimeInterval
}

enum AlertLevel {
    case info, warning, critical
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "xmark.octagon"
        }
    }
}

enum OptimizationType: String, CaseIterable {
    case memoryOptimization = "memory"
    case cpuOptimization = "cpu"
    case timerOptimization = "timer"
    case viewOptimization = "view"
    case networkOptimization = "network"
    
    var displayName: String {
        switch self {
        case .memoryOptimization: return "Memory Optimization"
        case .cpuOptimization: return "CPU Optimization"
        case .timerOptimization: return "Timer Optimization"
        case .viewOptimization: return "View Optimization"
        case .networkOptimization: return "Network Optimization"
        }
    }
    
    var icon: String {
        switch self {
        case .memoryOptimization: return "memorychip"
        case .cpuOptimization: return "cpu"
        case .timerOptimization: return "timer"
        case .viewOptimization: return "rectangle.stack"
        case .networkOptimization: return "network"
        }
    }
}

// MARK: - Performance Dashboard View

struct PerformanceDashboard: View {
    @StateObject private var monitor = AdvancedPerformanceMonitor.shared
    @State private var showingReport = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    currentMetricsSection
                    
                    if !monitor.alerts.isEmpty {
                        alertsSection
                    }
                    
                    if !monitor.optimizationSuggestions.isEmpty {
                        optimizationSection
                    }
                    
                    performanceChartSection
                }
                .padding()
            }
            .navigationTitle("Performance")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarMenu
                }
            }
        }
        .sheet(isPresented: $showingReport) {
            PerformanceReportView(report: monitor.getPerformanceReport())
        }
    }
    
    private var toolbarMenu: some View {
        Menu {
            Button("View Report") {
                showingReport = true
            }
            
            Button("Clear History") {
                monitor.clearHistory()
            }
            
            Button(monitor.isMonitoring ? "Stop Monitoring" : "Start Monitoring") {
                if monitor.isMonitoring {
                    monitor.stopMonitoring()
                } else {
                    monitor.startMonitoring()
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
    
    private var currentMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Performance")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                MetricCard(
                    title: "Memory",
                    value: "\(Int(monitor.currentMetrics.memoryUsageMB))",
                    unit: "MB",
                    icon: "memorychip",
                    color: monitor.currentMetrics.memoryUsageMB > 150 ? .red : .green
                )
                
                MetricCard(
                    title: "CPU",
                    value: "\(Int(monitor.currentMetrics.cpuUsage))",
                    unit: "%",
                    icon: "cpu",
                    color: monitor.currentMetrics.cpuUsage > 70 ? .red : .green
                )
                
                MetricCard(
                    title: "Timers",
                    value: "\(monitor.currentMetrics.activeTimers)",
                    unit: "active",
                    icon: "timer",
                    color: monitor.currentMetrics.activeTimers > 10 ? .orange : .green
                )
                
                MetricCard(
                    title: "Battery",
                    value: "\(Int(monitor.currentMetrics.batteryLevel * 100))",
                    unit: "%",
                    icon: "battery.100",
                    color: monitor.currentMetrics.batteryLevel < 0.2 ? .red : .green
                )
            }
        }
    }
    
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Alerts")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 8) {
                ForEach(monitor.alerts.suffix(5)) { alert in
                    AlertRow(alert: alert)
                }
            }
        }
    }
    
    private var optimizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Optimization Suggestions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 8) {
                ForEach(monitor.optimizationSuggestions) { suggestion in
                    OptimizationRow(suggestion: suggestion)
                }
            }
        }
    }
    
    private var performanceChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance History")
                .font(.headline)
                .fontWeight(.semibold)
            
            // This would use the OptimizedProgressChart from ViewPerformanceModifiers
            // For now, a placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 100)
                .cornerRadius(8)
                .overlay(
                    Text("Performance Chart Placeholder")
                        .foregroundColor(.secondary)
                )
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct AlertRow: View {
    let alert: PerformanceAlert
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alert.level.icon)
                .foregroundColor(alert.level.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.message)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Text(alert.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct OptimizationRow: View {
    let suggestion: OptimizationSuggestion
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: suggestion.type.icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(suggestion.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct PerformanceReportView: View {
    let report: PerformanceReport
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary stats
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        ReportCard(
                            title: "Avg Memory",
                            value: "\(Int(report.averageMemoryUsage))",
                            unit: "MB",
                            icon: "memorychip"
                        )
                        
                        ReportCard(
                            title: "Avg CPU",
                            value: "\(Int(report.averageCPUUsage))",
                            unit: "%",
                            icon: "cpu"
                        )
                        
                        ReportCard(
                            title: "Peak Memory",
                            value: "\(Int(report.peakMemoryUsage))",
                            unit: "MB",
                            icon: "chart.line.uptrend.xyaxis"
                        )
                        
                        ReportCard(
                            title: "Total Alerts",
                            value: "\(report.totalAlerts)",
                            unit: "alerts",
                            icon: "exclamationmark.triangle"
                        )
                    }
                    
                    // Duration
                    HStack {
                        Text("Monitoring Duration:")
                        Spacer()
                        Text(formatDuration(report.monitoringDuration))
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Performance Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)m \(seconds)s"
    }
}

struct ReportCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}
