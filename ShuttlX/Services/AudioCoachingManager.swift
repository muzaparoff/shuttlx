//
//  AudioCoachingManager.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import AVFoundation
import Speech
import Combine

// MARK: - Audio Coaching Configuration
struct AudioCoachingSettings: Codable {
    var isEnabled: Bool = true
    var voice: VoiceType = .female
    var language: AudioLanguage = .english
    var intervalAnnouncements: Bool = true
    var progressUpdates: Bool = true
    var motivationalCoaching: Bool = true
    var heartRateAlerts: Bool = true
    var paceGuidance: Bool = true
    var formTips: Bool = false
    var volume: Float = 0.8
    
    enum VoiceType: String, Codable, CaseIterable {
        case male, female, robotic
        
        var displayName: String {
            switch self {
            case .male: return "Male"
            case .female: return "Female"
            case .robotic: return "Robotic"
            }
        }
    }
    
    enum AudioLanguage: String, Codable, CaseIterable {
        case english = "en-US"
        case spanish = "es-ES"
        case french = "fr-FR"
        case german = "de-DE"
        case japanese = "ja-JP"
        
        var displayName: String {
            switch self {
            case .english: return "English"
            case .spanish: return "Spanish"
            case .french: return "French"
            case .german: return "German"
            case .japanese: return "Japanese"
            }
        }
    }
}

// MARK: - Coaching Message Types
enum CoachingMessageType {
    case workoutStart
    case workoutEnd
    case intervalStart(type: String, duration: Int)
    case intervalEnd
    case halfwayPoint
    case progress(completed: Int, total: Int)
    case heartRateZone(zone: String)
    case paceAdjustment(instruction: String)
    case motivation(phase: MotivationPhase)
    case form(tip: String)
    case countdown(seconds: Int)
    case achievement(type: String)
    
    enum MotivationPhase {
        case start, middle, struggle, finish, recovery
    }
}

// MARK: - Audio Coaching Manager
@MainActor
class AudioCoachingManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var settings = AudioCoachingSettings()
    @Published var isEnabled: Bool = true
    @Published var isSpeaking: Bool = false
    @Published var currentMessage: String?
    
    // MARK: - Private Properties
    private let synthesizer = AVSpeechSynthesizer()
    private var audioSession = AVAudioSession.sharedInstance()
    private var messageQueue: [CoachingMessageType] = []
    private var isProcessingQueue = false
    private var cancellables = Set<AnyCancellable>()
    private var lastMotivationTime = Date()
    private let motivationCooldown: TimeInterval = 120 // 2 minutes between motivational messages
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupAudioSession()
        synthesizer.delegate = self
        loadSettings()
    }
    
    // MARK: - Public Methods
    func configure(with settings: AudioCoachingSettings) {
        self.settings = settings
        self.isEnabled = settings.isEnabled
        saveSettings()
    }
    
    func speak(_ messageType: CoachingMessageType, priority: CoachingPriority = .normal) {
        guard isEnabled && settings.isEnabled else { return }
        
        switch priority {
        case .high:
            // Clear queue and speak immediately
            messageQueue.removeAll()
            messageQueue.append(messageType)
        case .normal:
            messageQueue.append(messageType)
        case .low:
            // Only add if queue is empty
            if messageQueue.isEmpty {
                messageQueue.append(messageType)
            }
        }
        
        processMessageQueue()
    }
    
    func speakCustomMessage(_ message: String, priority: CoachingPriority = .normal) {
        guard isEnabled && settings.isEnabled else { return }
        
        let customMessage = CoachingMessageType.achievement(type: message) // Using achievement as generic custom message
        speak(customMessage, priority: priority)
    }
    
    func startWorkoutCoaching() {
        speak(.workoutStart, priority: .high)
    }
    
    func endWorkoutCoaching() {
        speak(.workoutEnd, priority: .high)
    }
    
    func announceInterval(type: String, duration: Int) {
        guard settings.intervalAnnouncements else { return }
        speak(.intervalStart(type: type, duration: duration))
    }
    
    func announceProgress(completed: Int, total: Int) {
        guard settings.progressUpdates else { return }
        speak(.progress(completed: completed, total: total))
    }
    
    func announceHeartRate(zone: String) {
        guard settings.heartRateAlerts else { return }
        speak(.heartRateZone(zone: zone))
    }
    
    func providePaceGuidance(_ instruction: String) {
        guard settings.paceGuidance else { return }
        speak(.paceAdjustment(instruction: instruction))
    }
    
    func provideFormTip(_ tip: String) {
        guard settings.formTips else { return }
        speak(.form(tip: tip))
    }
    
    func provideMotivation(for phase: CoachingMessageType.MotivationPhase) {
        guard settings.motivationalCoaching else { return }
        
        // Check cooldown period
        let now = Date()
        if now.timeIntervalSince(lastMotivationTime) < motivationCooldown {
            return
        }
        
        lastMotivationTime = now
        speak(.motivation(phase: phase), priority: .low)
    }
    
    func startCountdown(from seconds: Int) {
        for i in (1...min(seconds, 10)).reversed() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(seconds - i)) {
                self.speak(.countdown(seconds: i), priority: .high)
            }
        }
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        messageQueue.removeAll()
        isSpeaking = false
        currentMessage = nil
    }
    
    // MARK: - Private Methods
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    private func processMessageQueue() {
        guard !isProcessingQueue && !messageQueue.isEmpty && !isSpeaking else { return }
        
        isProcessingQueue = true
        let messageType = messageQueue.removeFirst()
        let message = generateMessage(for: messageType)
        
        currentMessage = message
        speakMessage(message)
    }
    
    private func speakMessage(_ message: String) {
        let utterance = AVSpeechUtterance(string: message)
        
        // Configure voice
        if let voice = getVoice() {
            utterance.voice = voice
        }
        
        // Configure speech parameters
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = settings.volume
        
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    private func getVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let languageVoices = voices.filter { $0.language == settings.language.rawValue }
        
        switch settings.voice {
        case .male:
            return languageVoices.first { $0.gender == .male } ?? languageVoices.first
        case .female:
            return languageVoices.first { $0.gender == .female } ?? languageVoices.first
        case .robotic:
            // Use a more monotone voice or fallback to default
            return languageVoices.first
        }
    }
    
    private func generateMessage(for type: CoachingMessageType) -> String {
        switch type {
        case .workoutStart:
            return generateWorkoutStartMessage()
        case .workoutEnd:
            return generateWorkoutEndMessage()
        case .intervalStart(let intervalType, let duration):
            return generateIntervalStartMessage(type: intervalType, duration: duration)
        case .intervalEnd:
            return "Interval complete. Well done!"
        case .halfwayPoint:
            return "You're halfway through! Keep pushing!"
        case .progress(let completed, let total):
            return "Completed \(completed) of \(total) intervals. You're doing great!"
        case .heartRateZone(let zone):
            return generateHeartRateMessage(zone: zone)
        case .paceAdjustment(let instruction):
            return instruction
        case .motivation(let phase):
            return generateMotivationalMessage(for: phase)
        case .form(let tip):
            return "Form tip: \(tip)"
        case .countdown(let seconds):
            return seconds > 1 ? "\(seconds)" : "Go!"
        case .achievement(let type):
            return "Achievement unlocked: \(type)!"
        }
    }
    
    private func generateWorkoutStartMessage() -> String {
        let messages = [
            "Let's get started! You've got this!",
            "Time to crush this workout!",
            "Ready to push your limits? Let's go!",
            "Your journey to fitness starts now!",
            "Let's make every second count!"
        ]
        return messages.randomElement() ?? messages[0]
    }
    
    private func generateWorkoutEndMessage() -> String {
        let messages = [
            "Workout complete! You absolutely crushed it!",
            "Amazing work! You should be proud of yourself!",
            "That's how it's done! Fantastic effort!",
            "Workout finished! You're getting stronger every day!",
            "Incredible dedication! You've earned this rest!"
        ]
        return messages.randomElement() ?? messages[0]
    }
    
    private func generateIntervalStartMessage(type: String, duration: Int) -> String {
        let minutes = duration / 60
        let seconds = duration % 60
        
        let timeString = minutes > 0 
            ? "\(minutes) minute\(minutes == 1 ? "" : "s")" + (seconds > 0 ? " and \(seconds) seconds" : "")
            : "\(seconds) seconds"
        
        switch type.lowercased() {
        case "work":
            return "\(type) interval starting. \(timeString) of high intensity. Give it everything!"
        case "rest":
            return "Rest period. \(timeString) to recover. Breathe and prepare for the next round."
        case "warmup":
            return "Warm up time. \(timeString) to prepare your body. Start easy and build up."
        case "cooldown":
            return "Cool down period. \(timeString) to let your heart rate come down."
        default:
            return "\(type) interval. \(timeString). Stay focused!"
        }
    }
    
    private func generateHeartRateMessage(zone: String) -> String {
        switch zone.lowercased() {
        case "fat burn":
            return "You're in the fat burn zone. Steady pace!"
        case "cardio":
            return "Great cardio zone! This is where the magic happens!"
        case "peak":
            return "Peak heart rate zone! Push yourself but stay safe!"
        case "anaerobic":
            return "Anaerobic zone! Maximum effort!"
        default:
            return "Heart rate in \(zone) zone."
        }
    }
    
    private func generateMotivationalMessage(for phase: CoachingMessageType.MotivationPhase) -> String {
        switch phase {
        case .start:
            let messages = [
                "Here we go! Show this workout who's boss!",
                "You've trained for this moment. Time to shine!",
                "Remember why you started. Let's do this!"
            ]
            return messages.randomElement() ?? messages[0]
            
        case .middle:
            let messages = [
                "You're finding your rhythm now. Keep it up!",
                "Halfway through and looking strong!",
                "This is where champions are made. Stay focused!"
            ]
            return messages.randomElement() ?? messages[0]
            
        case .struggle:
            let messages = [
                "I know it's tough, but you're tougher! Keep going!",
                "This is where you prove to yourself what you're made of!",
                "Pain is temporary, but pride lasts forever!",
                "You've overcome challenges before. You've got this!"
            ]
            return messages.randomElement() ?? messages[0]
            
        case .finish:
            let messages = [
                "Final push! Leave everything on the table!",
                "You can see the finish line! Sprint to the end!",
                "This is it! Show me what you've got left!"
            ]
            return messages.randomElement() ?? messages[0]
            
        case .recovery:
            let messages = [
                "Take your time to recover. You've earned it!",
                "Breathe deep and let your body recover.",
                "Recovery is part of the process. Well done!"
            ]
            return messages.randomElement() ?? messages[0]
        }
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "AudioCoachingSettings")
        }
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "AudioCoachingSettings"),
           let savedSettings = try? JSONDecoder().decode(AudioCoachingSettings.self, from: data) {
            self.settings = savedSettings
            self.isEnabled = savedSettings.isEnabled
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension AudioCoachingManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            currentMessage = nil
            isProcessingQueue = false
            
            // Process next message in queue
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.processMessageQueue()
            }
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            currentMessage = nil
            isProcessingQueue = false
        }
    }
}

// MARK: - Supporting Types
enum CoachingPriority {
    case high    // Interrupts current speech
    case normal  // Queued in order
    case low     // Only if queue is empty
}

// MARK: - Extensions
extension AVSpeechSynthesisVoice {
    var gender: Gender {
        // This is a simplified approach - in reality, you'd need to check voice characteristics
        let name = self.name.lowercased()
        if name.contains("female") || name.contains("woman") || name.contains("sara") || name.contains("alice") {
            return .female
        } else if name.contains("male") || name.contains("man") || name.contains("alex") || name.contains("daniel") {
            return .male
        }
        return .unknown
    }
    
    enum Gender {
        case male, female, unknown
    }
}
