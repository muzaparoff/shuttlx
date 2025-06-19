import Foundation
import SwiftUI
import MapKit
import CoreLocation
import Combine
import HealthKit
import WatchConnectivity

// MARK: - WorkoutViewModel
@MainActor
class WorkoutViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var workoutState: WorkoutState = .preparing
    @Published var workoutType: SimpleWorkoutType = .intervalRunning
    @Published var currentSession: WorkoutSession?
    @Published var currentInterval: SimpleWorkoutInterval?
    @Published var currentIntervalIndex: Int = 0
    @Published var nextInterval: SimpleWorkoutInterval?
    @Published var timerProgress: Double = 0.0
    @Published var workoutProgress: Double = 0.0
    @Published var isTrackingLocation: Bool = true
    @Published var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @Published var routePoints: [RoutePoint] = []
    
    // MARK: - Computed Properties for UI
    var currentTimeText: String {
        guard let interval = currentInterval else { return "00:00" }
        let remainingTime = max(0, interval.duration - currentIntervalElapsedTime)
        return formatTime(remainingTime)
    }
    
    var elapsedTimeText: String {
        guard let session = currentSession else { return "00:00" }
        return formatTime(session.duration)
    }
    
    var totalIntervals: Int {
        return currentSession?.intervals.count ?? 0
    }
    
    var estimatedCalories: Double {
        guard let session = currentSession else { return 0 }
        // Simple calorie estimation: 10 calories per minute for moderate intensity
        let minutes = session.duration / 60.0
        let intensityMultiplier = getIntensityMultiplier()
        return minutes * 10.0 * intensityMultiplier
    }
    
    var totalDistance: Double? {
        guard let session = currentSession, !session.locationData.isEmpty else { return nil }
        // Calculate total distance from location points
        var distance = 0.0
        for i in 1..<session.locationData.count {
            let prev = CLLocation(
                latitude: session.locationData[i-1].coordinate.latitude,
                longitude: session.locationData[i-1].coordinate.longitude
            )
            let current = CLLocation(
                latitude: session.locationData[i].coordinate.latitude,
                longitude: session.locationData[i].coordinate.longitude
            )
            distance += prev.distance(from: current)
        }
        return distance / 1000.0 // Convert to kilometers
    }
    
    var averageHeartRate: Double? {
        guard let session = currentSession, !session.heartRateData.isEmpty else { return nil }
        let totalHeartRate = session.heartRateData.reduce(0) { $0 + $1.heartRate }
        return totalHeartRate / Double(session.heartRateData.count)
    }
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var intervalTimer: Timer?
    private var currentIntervalElapsedTime: TimeInterval = 0
    private var locationManager: CLLocationManager?
    private var cancellables = Set<AnyCancellable>()
    private let performanceService = PerformanceOptimizationService.shared
    
    // MARK: - Memory Management
    private let maxLocationPoints = 500 // Reduced from 1000
    private let maxHeartRatePoints = 100 // Keep manageable
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationManager()
        setupSampleWorkout()
        setupPerformanceOptimization()
    }
    
    deinit {
        // Ensure cleanup - capture service weakly to avoid deinit capture warning
        let performanceService = self.performanceService
        Task { @MainActor in
            performanceService.invalidateTimer(identifier: "workout_main")
            performanceService.invalidateTimer(identifier: "workout_interval")
        }
        locationManager?.stopUpdatingLocation()
        cancellables.removeAll()
    }
    
    // MARK: - Public Methods
    func startWorkout() {
        guard workoutState != .active else { return }
        
        if currentSession == nil {
            createNewSession()
        }
        
        workoutState = .active
        startTimers()
        startLocationTracking()
        
        // Audio coaching and accessibility announcements
        // audioCoachingManager.startWorkoutCoaching()
        // accessibilityManager.announceWorkoutStart(type: workoutType.displayName)
        // accessibilityManager.provideHapticFeedback(for: .intervalStart)
        
        print("🏃‍♂️ Workout started: \(workoutType.displayName)")
    }
    
    func pauseWorkout() {
        guard workoutState == .active else { return }
        
        workoutState = .paused
        stopTimers()
        
        print("⏸️ Workout paused")
    }
    
    func resumeWorkout() {
        guard workoutState == .paused else { return }
        
        workoutState = .active
        startTimers()
        
        print("▶️ Workout resumed")
    }
    
    func endWorkout() {
        workoutState = .completed
        stopTimers()
        stopLocationTracking()
        
        currentSession?.endTime = Date()
        
        // Save workout data
        saveWorkoutSession()
        
        // Audio coaching and accessibility announcements
        // audioCoachingManager.endWorkoutCoaching()
        // accessibilityManager.announceWorkoutEnd(duration: elapsedTimeText)
        // accessibilityManager.provideHapticFeedback(for: .workoutComplete)
        
        print("🏁 Workout completed: \(elapsedTimeText)")
    }
    
    private func saveWorkoutSession() {
        guard let session = currentSession else {
            print("❌ Cannot save workout: no session data")
            return
        }
        
        print("💾 Saving iOS workout session...")
        
        // Create workout results
        let results = WorkoutResults(
            workoutId: UUID(),
            startDate: session.startTime,
            endDate: session.endTime ?? Date(),
            totalDuration: session.duration,
            activeCalories: estimatedCalories,
            heartRate: averageHeartRate ?? 0,
            distance: totalDistance ?? 0,
            completedIntervals: currentIntervalIndex,
            averageHeartRate: averageHeartRate ?? 0,
            maxHeartRate: averageHeartRate ?? 0 // TODO: Track actual max
        )
        
        do {
            // Save to UserDefaults for persistence
            let data = try JSONEncoder().encode(results)
            UserDefaults.standard.set(data, forKey: "lastWorkoutResults_iOS")
            
            // Also save to a list of all completed workouts
            var allWorkouts: [WorkoutResults] = []
            if let existingData = UserDefaults.standard.data(forKey: "completedWorkouts_iOS"),
               let existing = try? JSONDecoder().decode([WorkoutResults].self, from: existingData) {
                allWorkouts = existing
            }
            allWorkouts.append(results)
            
            // Keep only last 50 workouts to prevent excessive storage
            if allWorkouts.count > 50 {
                allWorkouts = Array(allWorkouts.suffix(50))
            }
            
            let allWorkoutsData = try JSONEncoder().encode(allWorkouts)
            UserDefaults.standard.set(allWorkoutsData, forKey: "completedWorkouts_iOS")
            
            print("✅ iOS workout data saved successfully")
            print("   - Duration: \(session.duration)s")
            print("   - Estimated Calories: \(estimatedCalories)")
            print("   - Intervals completed: \(currentIntervalIndex)/\(session.intervals.count)")
            print("   - Distance: \(totalDistance ?? 0)km")
            print("   - Location points: \(routePoints.count)")
            
        } catch {
            print("❌ Failed to save iOS workout data: \(error.localizedDescription)")
        }
    }
    
    func skipInterval() {
        moveToNextInterval()
    }
    
    // MARK: - Private Methods
    private func setupSampleWorkout() {
        // Create a sample interval workout
        workoutType = .intervalRunning
        
        let intervals: [SimpleWorkoutInterval] = [
            SimpleWorkoutInterval(type: .work, duration: 30, intensity: .vigorous, instructions: "High intensity sprint"),
            SimpleWorkoutInterval(type: .rest, duration: 30, intensity: .light, instructions: "Active recovery walk"),
            SimpleWorkoutInterval(type: .work, duration: 30, intensity: .vigorous, instructions: "High intensity sprint"),
            SimpleWorkoutInterval(type: .rest, duration: 30, intensity: .light, instructions: "Active recovery walk"),
            SimpleWorkoutInterval(type: .work, duration: 30, intensity: .vigorous, instructions: "High intensity sprint"),
            SimpleWorkoutInterval(type: .rest, duration: 30, intensity: .light, instructions: "Active recovery walk"),
            SimpleWorkoutInterval(type: .work, duration: 30, intensity: .vigorous, instructions: "High intensity sprint"),
            SimpleWorkoutInterval(type: .rest, duration: 30, intensity: .light, instructions: "Active recovery walk")
        ]
        
        currentSession = WorkoutSession(
            workoutType: workoutType,
            startTime: Date(),
            intervals: intervals
        )
        
        currentInterval = intervals.first
        updateNextInterval()
    }
    
    private func createNewSession() {
        currentSession = WorkoutSession(
            workoutType: workoutType,
            startTime: Date()
        )
        currentIntervalIndex = 0
        currentIntervalElapsedTime = 0
    }
    
    private func startTimers() {
        // Use optimized timer service to prevent memory leaks
        timer = performanceService.createOptimizedTimer(
            identifier: "workout_main",
            interval: 1.0
        ) { [weak self] in
            Task { @MainActor in
                self?.updateWorkoutProgress()
            }
        }
        
        // Interval timer for current interval progress
        intervalTimer = performanceService.createOptimizedTimer(
            identifier: "workout_interval",
            interval: 0.1
        ) { [weak self] in
            Task { @MainActor in
                self?.updateIntervalProgress()
            }
        }
    }
    
    private func stopTimers() {
        performanceService.invalidateTimer(identifier: "workout_main")
        performanceService.invalidateTimer(identifier: "workout_interval")
        timer = nil
        intervalTimer = nil
    }
    
    private func updateWorkoutProgress() {
        guard let session = currentSession else { return }
        
        // Update overall workout progress
        let totalDuration = session.intervals.reduce(0) { $0 + $1.duration }
        let elapsedDuration = session.duration
        workoutProgress = min(1.0, elapsedDuration / totalDuration)
        
        // Simulate heart rate data
        addSimulatedHeartRateData()
        
        // Periodic progress announcements
        let intervalMinute = Int(elapsedDuration) / 60
        if intervalMinute > 0 && Int(elapsedDuration) % 120 == 0 { // Every 2 minutes
            let remainingTime = totalDuration - elapsedDuration
            let _ = formatTime(remainingTime)
            
            // audioCoachingManager.announceProgress(
            //     completed: currentIntervalIndex + 1,
            //     total: session.intervals.count
            // )
            
            // accessibilityManager.announceProgress(
            //     completed: currentIntervalIndex + 1,
            //     total: session.intervals.count,
            //     timeRemaining: timeRemaining
            // )
        }
        
        // Heart rate zone announcements
        if let avgHeartRate = averageHeartRate, Int(elapsedDuration) % 180 == 0 { // Every 3 minutes
            let _ = getHeartRateZone(heartRate: avgHeartRate)
            // audioCoachingManager.announceHeartRate(zone: zone)
            // accessibilityManager.announceHeartRate(current: Int(avgHeartRate), zone: zone)
        }
    }
    
    private func updateIntervalProgress() {
        guard let interval = currentInterval, workoutState == .active else { return }
        
        currentIntervalElapsedTime += 0.1
        timerProgress = min(1.0, currentIntervalElapsedTime / interval.duration)
        
        // Check if current interval is complete
        if currentIntervalElapsedTime >= interval.duration {
            moveToNextInterval()
        }
    }
    
    private func moveToNextInterval() {
        guard let session = currentSession else { return }
        
        // Announce interval completion
        if currentInterval != nil {
            // accessibilityManager.provideHapticFeedback(for: .intervalEnd)
        }
        
        // Move to next interval
        currentIntervalIndex += 1
        currentIntervalElapsedTime = 0
        timerProgress = 0
        
        if currentIntervalIndex < session.intervals.count {
            currentInterval = session.intervals[currentIntervalIndex]
            updateNextInterval()
            
            // Announce new interval
            if currentInterval != nil {
                // audioCoachingManager.announceInterval(
                //     type: interval.type.displayName,
                //     duration: Int(interval.duration)
                // )
                
                let _ = nextInterval?.type.displayName
                // accessibilityManager.announceIntervalChange(
                //     current: interval.type.displayName,
                //     next: nextIntervalText
                // )
                
                // accessibilityManager.provideHapticFeedback(for: .intervalStart)
                
                // Provide motivational coaching based on workout phase
                if currentIntervalIndex == 1 {
                    // audioCoachingManager.provideMotivation(for: .start)
                } else if currentIntervalIndex > session.intervals.count / 2 {
                    // audioCoachingManager.provideMotivation(for: .finish)
                } else {
                    // audioCoachingManager.provideMotivation(for: .middle)
                }
            }
        } else {
            // Workout completed
            endWorkout()
        }
    }
    
    private func updateNextInterval() {
        guard let session = currentSession else { return }
        
        let nextIndex = currentIntervalIndex + 1
        if nextIndex < session.intervals.count {
            nextInterval = session.intervals[nextIndex]
        } else {
            nextInterval = nil
        }
    }
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.requestWhenInUseAuthorization()
    }
    
    private func startLocationTracking() {
        guard isTrackingLocation else { return }
        locationManager?.startUpdatingLocation()
    }
    
    private func stopLocationTracking() {
        locationManager?.stopUpdatingLocation()
    }
    
    private func addSimulatedHeartRateData() {
        guard let interval = currentInterval else { return }
        
        // Simulate heart rate based on interval type and intensity
        let baseHeartRate = getBaseHeartRate(for: interval.intensity)
        let variation = Double.random(in: -10...10)
        let heartRate = max(60, min(200, baseHeartRate + variation))
        
        let dataPoint = HeartRateDataPoint(timestamp: Date(), heartRate: heartRate)
        currentSession?.heartRateData.append(dataPoint)
        
        // Keep only last maxHeartRatePoints data points to manage memory
        if currentSession?.heartRateData.count ?? 0 > maxHeartRatePoints {
            let excessCount = (currentSession?.heartRateData.count ?? 0) - maxHeartRatePoints
            currentSession?.heartRateData.removeFirst(excessCount)
        }
    }
    
    private func getBaseHeartRate(for intensity: ExerciseIntensity) -> Double {
        let maxHR = 190.0 // Simplified max heart rate
        
        switch intensity {
        case .veryLight: return maxHR * 0.6
        case .light: return maxHR * 0.7
        case .moderate: return maxHR * 0.8
        case .vigorous: return maxHR * 0.85
        case .maximal: return maxHR * 0.95
        }
    }
    
    private func getIntensityMultiplier() -> Double {
        guard let interval = currentInterval else { return 1.0 }
        
        switch interval.intensity {
        case .veryLight: return 0.5
        case .light: return 0.7
        case .moderate: return 1.0
        case .vigorous: return 1.3
        case .maximal: return 1.6
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func getHeartRateZone(heartRate: Double) -> String {
        let maxHR = 190.0 // Simplified max heart rate
        let percentage = heartRate / maxHR
        
        switch percentage {
        case 0.0..<0.6:
            return "Active Recovery"
        case 0.6..<0.7:
            return "Base Training"
        case 0.7..<0.8:
            return "Aerobic Base"
        case 0.8..<0.9:
            return "Lactate Threshold"
        case 0.9..<0.95:
            return "VO2 Max"
        default:
            return "Peak"
        }
    }
    
    // MARK: - Placeholder for Future Services
    // Note: These will be implemented in future versions
    private func getAudioCoachingFeedback() -> String {
        return "Great job! Keep it up!"
    }
    
    private func checkAccessibilitySettings() -> Bool {
        return true
    }
    
    // MARK: - Performance Optimization
    private func setupPerformanceOptimization() {
        // Schedule periodic memory cleanup
        _ = performanceService.createOptimizedTimer(
            identifier: "memory_cleanup",
            interval: 30.0 // Every 30 seconds
        ) { [weak self] in
            self?.performanceService.performMemoryCleanup()
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension WorkoutViewModel: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            guard workoutState == .active else { return }
            
            // Update map region
            mapRegion.center = location.coordinate
            
            // Add route point
            let routePoint = RoutePoint(coordinate: location.coordinate, timestamp: Date())
            routePoints.append(routePoint)
            
            // Add location data to session
            let locationData = LocationDataPoint(
                timestamp: Date(),
                coordinate: location.coordinate,
                altitude: location.altitude,
                speed: location.speed
            )
            currentSession?.locationData.append(locationData)
            
            // Keep only last maxLocationPoints location points to manage memory
            if routePoints.count > maxLocationPoints {
                routePoints.removeFirst(routePoints.count - maxLocationPoints)
            }
            
            if currentSession?.locationData.count ?? 0 > maxLocationPoints {
                let excessCount = (currentSession?.locationData.count ?? 0) - maxLocationPoints
                currentSession?.locationData.removeFirst(excessCount)
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
        Task { @MainActor in
            isTrackingLocation = false
        }
    }
}


