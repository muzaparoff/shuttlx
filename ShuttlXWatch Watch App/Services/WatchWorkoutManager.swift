import Foundation
import HealthKit
import WatchKit
import Combine
import WatchConnectivity

class WatchWorkoutManager: NSObject, ObservableObject {
    @Published var availablePrograms: [TrainingProgram] = []
    @Published var currentProgram: TrainingProgram?
    @Published var currentInterval: TrainingInterval?
    @Published var currentIntervalIndex: Int = 0
    @Published var isRunning = false
    @Published var isPaused = false
    
    // Timer and workout state
    @Published var elapsedTime: TimeInterval = 0
    @Published var intervalElapsedTime: TimeInterval = 0
    @Published var remainingTime: TimeInterval = 0
    @Published var intervalRemainingTime: TimeInterval = 0
    
    // Health metrics
    @Published var heartRate: Double = 0
    @Published var averageHeartRate: Double = 0
    @Published var maxHeartRate: Double = 0
    @Published var caloriesBurned: Double = 0
    @Published var distance: Double = 0
    
    // Workout session
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var timer: Timer?
    private var startDate: Date?
    
    // Current session data
    private var currentSession: TrainingSession?
    private var completedIntervals: [CompletedInterval] = []
    
    // WatchConnectivity
    private let session = WCSession.default
    
    override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    // MARK: - Program Management
    
    func loadPrograms() {
        // Load programs from WatchConnectivity or local storage
        loadFromConnectivity()
        loadFromLocalStorage()
    }
    
    func selectProgram(_ program: TrainingProgram) {
        currentProgram = program
        currentInterval = program.intervals.first
        currentIntervalIndex = 0
        resetTimers()
    }
    
    func resetProgram() {
        currentProgram = nil
        currentInterval = nil
        currentIntervalIndex = 0
        resetTimers()
        endWorkoutSession()
    }
    
    // MARK: - Workout Control
    
    func startWorkout() {
        guard let program = currentProgram else { return }
        
        isRunning = true
        isPaused = false
        startDate = Date()
        
        // Create training session
        currentSession = TrainingSession(
            programID: program.id,
            programName: program.name
        )
        currentSession?.startDate = startDate!
        
        // Start HealthKit workout session
        startHealthKitWorkout()
        
        // Start timer
        startTimer()
        
        // Provide haptic feedback
        WKInterfaceDevice.current().play(.start)
    }
    
    func pauseWorkout() {
        guard isRunning else { return }
        
        isPaused = true
        isRunning = false
        
        // Pause HealthKit session
        workoutSession?.pause()
        
        // Stop timer
        stopTimer()
        
        // Provide haptic feedback
        WKInterfaceDevice.current().play(.stop)
    }
    
    func resumeWorkout() {
        guard isPaused else { return }
        
        isPaused = false
        isRunning = true
        
        // Resume HealthKit session
        workoutSession?.resume()
        
        // Restart timer
        startTimer()
        
        // Provide haptic feedback
        WKInterfaceDevice.current().play(.start)
    }
    
    func toggleWorkout() {
        if isRunning {
            pauseWorkout()
        } else if isPaused {
            resumeWorkout()
        } else {
            startWorkout()
        }
    }
    
    func endWorkout() {
        isRunning = false
        isPaused = false
        
        // Complete current interval if running
        if currentInterval != nil && intervalElapsedTime > 0 {
            completeCurrentInterval()
        }
        
        // End HealthKit workout session
        endWorkoutSession()
        
        // Stop timer
        stopTimer()
        
        // Save completed session
        saveCompletedSession()
        
        // Reset state
        resetProgram()
        
        // Provide haptic feedback
        WKInterfaceDevice.current().play(.success)
    }
    
    // MARK: - Timer Management
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateTimers()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTimers() {
        guard isRunning else { return }
        
        elapsedTime += 1
        intervalElapsedTime += 1
        
        // Update remaining times
        if let program = currentProgram {
            remainingTime = program.totalDuration - elapsedTime
        }
        
        if let interval = currentInterval {
            intervalRemainingTime = interval.duration - intervalElapsedTime
            
            // Check if current interval is complete
            if intervalElapsedTime >= interval.duration {
                moveToNextInterval()
            }
        }
        
        // Update health metrics
        updateHealthMetrics()
    }
    
    private func resetTimers() {
        elapsedTime = 0
        intervalElapsedTime = 0
        remainingTime = currentProgram?.totalDuration ?? 0
        intervalRemainingTime = currentInterval?.duration ?? 0
        
        // Reset health metrics
        heartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        caloriesBurned = 0
        distance = 0
    }
    
    // MARK: - Interval Management
    
    private func moveToNextInterval() {
        guard let program = currentProgram else { return }
        
        // Complete current interval
        completeCurrentInterval()
        
        // Move to next interval
        currentIntervalIndex += 1
        
        if currentIntervalIndex < program.intervals.count {
            currentInterval = program.intervals[currentIntervalIndex]
            intervalElapsedTime = 0
            intervalRemainingTime = currentInterval?.duration ?? 0
            
            // Provide haptic feedback for interval change
            WKInterfaceDevice.current().play(.notification)
        } else {
            // Workout complete
            endWorkout()
        }
    }
    
    private func completeCurrentInterval() {
        guard let interval = currentInterval,
              let startTime = startDate?.timeIntervalSinceNow else { return }
        
        let completedInterval = CompletedInterval(
            intervalID: interval.id,
            intervalType: interval.type,
            plannedDuration: interval.duration,
            startTime: abs(startTime) - intervalElapsedTime
        )
        
        var completed = completedInterval
        completed.complete(actualDuration: intervalElapsedTime)
        completed.averageHeartRate = averageHeartRate
        completed.maxHeartRate = maxHeartRate
        
        completedIntervals.append(completed)
    }
    
    // MARK: - HealthKit Integration
    
    func requestPermissions() {
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]
        
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if let error = error {
                print("HealthKit authorization failed: \(error)")
            }
        }
    }
    
    private func startHealthKitWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .functionalStrengthTraining
        configuration.locationType = .outdoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = workoutSession?.associatedWorkoutBuilder()
            
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            workoutSession?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { success, error in
                if let error = error {
                    print("Failed to start workout builder: \(error)")
                }
            }
        } catch {
            print("Failed to start workout session: \(error)")
        }
    }
    
    private func endWorkoutSession() {
        workoutSession?.end()
        builder?.endCollection(withEnd: Date()) { success, error in
            if let error = error {
                print("Failed to end workout builder: \(error)")
            }
        }
        
        workoutSession = nil
        builder = nil
    }
    
    private func updateHealthMetrics() {
        // This would be updated with real HealthKit data in a production app
        // For now, we'll simulate some values
        
        guard let program = currentProgram else { return }
        
        // Simulate heart rate based on interval type and max pulse
        if let interval = currentInterval {
            let baseRate = Double(program.maxPulse) * 0.6 // 60% of max
            let intensity = interval.type == .run ? 0.4 : 0.2 // Additional intensity
            let variation = Double.random(in: -10...10) // Random variation
            
            heartRate = baseRate + (Double(program.maxPulse) * intensity) + variation
            heartRate = max(60, min(Double(program.maxPulse), heartRate))
            
            // Update averages
            if averageHeartRate == 0 {
                averageHeartRate = heartRate
            } else {
                averageHeartRate = (averageHeartRate + heartRate) / 2
            }
            
            maxHeartRate = max(maxHeartRate, heartRate)
        }
        
        // Simulate calories (rough estimate: 10 calories per minute)
        caloriesBurned = elapsedTime / 60 * 10
        
        // Simulate distance (rough estimate based on interval type)
        if let interval = currentInterval {
            let speed = interval.type == .run ? 2.5 : 1.2 // meters per second
            distance += speed // Add distance per second
        }
    }
    
    // MARK: - Data Persistence
    
    private func saveCompletedSession() {
        guard var session = currentSession else { return }
        
        session.complete()
        session.averageHeartRate = averageHeartRate
        session.maxHeartRate = maxHeartRate
        session.caloriesBurned = caloriesBurned
        session.distance = distance
        session.completedIntervals = completedIntervals
        
        // Save to local storage
        saveSessionToLocal(session)
        
        // Send to iPhone via WatchConnectivity
        sendSessionToiPhone(session)
        
        // Reset session data
        currentSession = nil
        completedIntervals = []
    }
    
    private func saveSessionToLocal(_ session: TrainingSession) {
        var sessions = loadSessionsFromLocal()
        sessions.append(session)
        
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: "watch_training_sessions")
        } catch {
            print("Failed to save session to local storage: \(error)")
        }
    }
    
    private func loadSessionsFromLocal() -> [TrainingSession] {
        guard let data = UserDefaults.standard.data(forKey: "watch_training_sessions") else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([TrainingSession].self, from: data)
        } catch {
            print("Failed to load sessions from local storage: \(error)")
            return []
        }
    }
    
    // MARK: - WatchConnectivity
    
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    private func loadFromConnectivity() {
        // Request programs from iPhone
        if session.isReachable {
            session.sendMessage(["request": "programs"], replyHandler: { response in
                if let programsData = response["programs"] as? Data {
                    do {
                        let programs = try JSONDecoder().decode([TrainingProgram].self, from: programsData)
                        DispatchQueue.main.async {
                            self.availablePrograms = programs
                        }
                    } catch {
                        print("Failed to decode programs from iPhone: \(error)")
                    }
                }
            }, errorHandler: { error in
                print("Failed to request programs from iPhone: \(error)")
            })
        }
    }
    
    private func loadFromLocalStorage() {
        // Load cached programs from local storage
        if let data = UserDefaults.standard.data(forKey: "cached_programs") {
            do {
                let programs = try JSONDecoder().decode([TrainingProgram].self, from: data)
                availablePrograms = programs
            } catch {
                print("Failed to load cached programs: \(error)")
            }
        }
    }
    
    private func sendSessionToiPhone(_ session: TrainingSession) {
        guard WCSession.default.isReachable else { return }
        
        do {
            let sessionData = try JSONEncoder().encode(session)
            WCSession.default.sendMessage(["session": sessionData], replyHandler: nil) { error in
                print("Failed to send session to iPhone: \(error)")
            }
        } catch {
            print("Failed to encode session for iPhone: \(error)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchWorkoutManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error)")
        } else {
            print("WCSession activated successfully")
            loadFromConnectivity()
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let programsData = message["programs"] as? Data {
            do {
                let programs = try JSONDecoder().decode([TrainingProgram].self, from: programsData)
                DispatchQueue.main.async {
                    self.availablePrograms = programs
                    // Cache programs locally
                    UserDefaults.standard.set(programsData, forKey: "cached_programs")
                }
            } catch {
                print("Failed to decode programs update: \(error)")
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("Received application context from iPhone")
        
        if let programsData = applicationContext["programs"] as? Data {
            do {
                let programs = try JSONDecoder().decode([TrainingProgram].self, from: programsData)
                DispatchQueue.main.async {
                    self.availablePrograms = programs
                    // Cache programs locally
                    UserDefaults.standard.set(programsData, forKey: "cached_programs")
                    print("Updated \(programs.count) programs from iPhone context")
                }
            } catch {
                print("Failed to decode programs from application context: \(error)")
            }
        }
    }
}
