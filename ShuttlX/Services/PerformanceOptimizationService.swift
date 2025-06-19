//
//  PerformanceOptimizationService.swift
//  ShuttlX
//
//  Performance optimization service for the ShuttlX fitness app
//  Created by ShuttlX on 6/9/25.
//

import Foundation
import SwiftUI
import Combine

/// Central service for managing app performance optimizations
@MainActor
class PerformanceOptimizationService: ObservableObject {
    static let shared = PerformanceOptimizationService()
    
    // MARK: - Memory Management
    @Published private(set) var memoryUsage: MemoryUsage = .normal
    @Published private(set) var cpuUsage: Double = 0.0
    
    // MARK: - View Performance
    private var viewUpdateQueue = DispatchQueue(label: "viewUpdates", qos: .userInteractive)
    private var backgroundQueue = DispatchQueue(label: "background", qos: .background)
    
    // MARK: - Timer Management
    private var optimizedTimers: [String: Timer] = [:]
    private var timerCleanupScheduled = false
    
    private init() {
        setupPerformanceMonitoring()
    }
    
    // MARK: - Memory Optimization
    
    /// Optimized view updates with debouncing
    func debounceViewUpdate<T: ObservableObject>(
        for object: T,
        delay: TimeInterval = 0.1,
        action: @escaping () -> Void
    ) {
        viewUpdateQueue.asyncAfter(deadline: .now() + delay) {
            DispatchQueue.main.async {
                action()
            }
        }
    }
    
    /// Memory-efficient data loading with pagination
    func loadDataWithPagination<T>(
        data: [T],
        pageSize: Int = 50,
        currentPage: Int = 0
    ) -> [T] {
        let startIndex = currentPage * pageSize
        let endIndex = min(startIndex + pageSize, data.count)
        
        guard startIndex < data.count else { return [] }
        return Array(data[startIndex..<endIndex])
    }
    
    /// Clean up unused resources
    func performMemoryCleanup() {
        backgroundQueue.async { [weak self] in
            Task { @MainActor in
                self?.cleanupTimers()
                self?.cleanupCaches()
                self?.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Timer Optimization
    
    /// Create optimized timer with automatic cleanup
    func createOptimizedTimer(
        identifier: String,
        interval: TimeInterval,
        repeats: Bool = true,
        action: @escaping () -> Void
    ) -> Timer {
        // Clean up existing timer if any
        optimizedTimers[identifier]?.invalidate()
        
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { [weak self] timer in
            action()
            
            if !repeats {
                Task { @MainActor in
                    self?.optimizedTimers.removeValue(forKey: identifier)
                }
            }
        }
        
        optimizedTimers[identifier] = timer
        scheduleTimerCleanup()
        
        return timer
    }
    
    /// Invalidate specific timer
    func invalidateTimer(identifier: String) {
        optimizedTimers[identifier]?.invalidate()
        optimizedTimers.removeValue(forKey: identifier)
    }
    
    /// Invalidate all timers
    func invalidateAllTimers() {
        optimizedTimers.values.forEach { $0.invalidate() }
        optimizedTimers.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func setupPerformanceMonitoring() {
        // Start periodic performance monitoring
        _ = createOptimizedTimer(identifier: "performance_monitor", interval: 5.0) { [weak self] in
            self?.updatePerformanceMetrics()
        }
    }
    
    private func updatePerformanceMetrics() {
        // Simplified performance monitoring
        var memInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kr: kern_return_t = withUnsafeMutablePointer(to: &memInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kr == KERN_SUCCESS {
            let usedMB = Double(memInfo.resident_size) / (1024 * 1024)
            
            // Update memory usage status
            if usedMB > 150 {
                memoryUsage = .high
            } else if usedMB > 100 {
                memoryUsage = .moderate
            } else {
                memoryUsage = .normal
            }
        }
    }
    
    private func scheduleTimerCleanup() {
        guard !timerCleanupScheduled else { return }
        
        timerCleanupScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            self?.cleanupInvalidTimers()
            self?.timerCleanupScheduled = false
        }
    }
    
    private func cleanupTimers() {
        let invalidTimers = optimizedTimers.filter { !$0.value.isValid }
        invalidTimers.keys.forEach { key in
            optimizedTimers.removeValue(forKey: key)
        }
    }
    
    private func cleanupInvalidTimers() {
        cleanupTimers()
    }
    
    private func cleanupCaches() {
        // Remove old cache entries
        URLCache.shared.removeAllCachedResponses()
    }
}

// MARK: - Performance Data Models

enum MemoryUsage {
    case normal, moderate, high
    
    var description: String {
        switch self {
        case .normal: return "Normal"
        case .moderate: return "Moderate"
        case .high: return "High"
        }
    }
    
    var color: Color {
        switch self {
        case .normal: return .green
        case .moderate: return .orange
        case .high: return .red
        }
    }
}

// MARK: - SwiftUI Performance Extensions

extension View {
    /// Optimized animation modifier with reduced CPU usage
    func optimizedAnimation<V: Equatable>(
        _ animation: Animation?,
        value: V
    ) -> some View {
        self.animation(animation, value: value)
            .drawingGroup() // Optimize for complex animations
    }
    
    /// Memory-efficient list rendering
    func optimizedForLists() -> some View {
        self.buttonStyle(PlainButtonStyle()) // Reduce button overhead
            .clipped() // Improve scrolling performance
    }
    
    /// Debounced appearance handler
    func onOptimizedAppear(
        delay: TimeInterval = 0.1,
        action: @escaping () -> Void
    ) -> some View {
        self.onAppear {
            PerformanceOptimizationService.shared.debounceViewUpdate(
                for: PerformanceOptimizationService.shared,
                delay: delay,
                action: action
            )
        }
    }
}

// MARK: - Timer Extensions

extension Timer {
    /// Create a weak-self timer to prevent retain cycles
    static func weakScheduledTimer<T: AnyObject>(
        withTimeInterval interval: TimeInterval,
        target: T,
        repeats: Bool,
        action: @escaping (T) -> Void
    ) -> Timer {
        return Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { [weak target] _ in
            guard let target = target else { return }
            action(target)
        }
    }
}
