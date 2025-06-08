import Foundation
import CoreML
import Vision
import AVFoundation
import Combine
import SwiftUI

class FormAnalysisManager: NSObject, ObservableObject {
    @Published var isAnalyzing = false
    @Published var currentFormScore: Double = 0.0
    @Published var formFeedback: [FormFeedback] = []
    @Published var realTimeAnalysis: RealTimeAnalysis?
    @Published var analysisHistory: [FormAnalysisResult] = []
    
    private var cancellables = Set<AnyCancellable>()
    private var visionModel: VNCoreMLModel?
    private var analysisTimer: Timer?
    
    // Camera session for real-time analysis
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "form.analysis.session")
    
    override init() {
        super.init()
        setupCoreMLModel()
        setupCameraSession()
    }
    
    private func setupCoreMLModel() {
        // In a real implementation, you would load your trained Core ML model
        // For this demo, we'll simulate the model behavior
        
        // Example model loading (commented out for demo):
        /*
        guard let modelURL = Bundle.main.url(forResource: "ShuttleRunFormAnalysis", withExtension: "mlmodelc"),
              let model = try? MLModel(contentsOf: modelURL),
              let visionModel = try? VNCoreMLModel(for: model) else {
            print("Failed to load Core ML model")
            return
        }
        self.visionModel = visionModel
        */
        
        // For demo purposes, we'll use a mock model
        print("Form analysis model initialized (mock)")
    }
    
    private func setupCameraSession() {
        // Configure camera session for body pose detection
        captureSession.sessionPreset = .medium
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoDeviceInput) else {
            print("Failed to setup camera for form analysis")
            return
        }
        
        captureSession.addInput(videoDeviceInput)
        
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
    }
    
    func startFormAnalysis() {
        guard !isAnalyzing else { return }
        
        isAnalyzing = true
        formFeedback.removeAll()
        
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
        
        // Start periodic analysis
        analysisTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.performPeriodicAnalysis()
        }
        
        print("Form analysis started")
    }
    
    func stopFormAnalysis() {
        guard isAnalyzing else { return }
        
        isAnalyzing = false
        analysisTimer?.invalidate()
        analysisTimer = nil
        
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
        
        // Save analysis session
        saveAnalysisSession()
        
        print("Form analysis stopped")
    }
    
    private func performPeriodicAnalysis() {
        // Simulate form analysis with mock data
        let mockAnalysis = generateMockAnalysis()
        
        DispatchQueue.main.async { [weak self] in
            self?.realTimeAnalysis = mockAnalysis
            self?.currentFormScore = mockAnalysis.overallScore
            self?.formFeedback = mockAnalysis.feedback
        }
    }
    
    private func generateMockAnalysis() -> RealTimeAnalysis {
        // Simulate realistic form analysis data
        let formAspects = [
            FormAspect(name: "Posture", score: Double.random(in: 0.7...0.95), ideal: "Keep back straight"),
            FormAspect(name: "Foot Strike", score: Double.random(in: 0.6...0.9), ideal: "Land on forefoot"),
            FormAspect(name: "Arm Movement", score: Double.random(in: 0.8...0.95), ideal: "Pump arms rhythmically"),
            FormAspect(name: "Pace Consistency", score: Double.random(in: 0.7...0.9), ideal: "Maintain steady pace"),
            FormAspect(name: "Turn Technique", score: Double.random(in: 0.5...0.85), ideal: "Sharp, controlled turns")
        ]
        
        let overallScore = formAspects.map { $0.score }.reduce(0, +) / Double(formAspects.count)
        
        let feedback = generateFeedbackForScore(overallScore)
        
        return RealTimeAnalysis(
            timestamp: Date(),
            overallScore: overallScore,
            aspects: formAspects,
            feedback: feedback,
            keyPoints: detectKeyBodyPoints()
        )
    }
    
    private func generateFeedbackForScore(_ score: Double) -> [FormFeedback] {
        var feedback: [FormFeedback] = []
        
        if score < 0.7 {
            feedback.append(FormFeedback(
                type: .warning,
                message: "Focus on maintaining proper form",
                suggestion: "Slow down and concentrate on technique",
                priority: .high
            ))
        }
        
        if score >= 0.8 {
            feedback.append(FormFeedback(
                type: .positive,
                message: "Excellent form! Keep it up!",
                suggestion: "You're running efficiently",
                priority: .low
            ))
        } else {
            feedback.append(FormFeedback(
                type: .improvement,
                message: "Good effort, small adjustments needed",
                suggestion: "Focus on your turning technique",
                priority: .medium
            ))
        }
        
        return feedback
    }
    
    private func detectKeyBodyPoints() -> [BodyKeyPoint] {
        // Simulate body key point detection
        return [
            BodyKeyPoint(name: "Head", position: CGPoint(x: 0.5, y: 0.1), confidence: 0.95),
            BodyKeyPoint(name: "Shoulders", position: CGPoint(x: 0.5, y: 0.25), confidence: 0.9),
            BodyKeyPoint(name: "Hips", position: CGPoint(x: 0.5, y: 0.55), confidence: 0.88),
            BodyKeyPoint(name: "Knees", position: CGPoint(x: 0.5, y: 0.75), confidence: 0.85),
            BodyKeyPoint(name: "Feet", position: CGPoint(x: 0.5, y: 0.95), confidence: 0.92)
        ]
    }
    
    private func saveAnalysisSession() {
        guard let realTimeAnalysis = realTimeAnalysis else { return }
        
        let result = FormAnalysisResult(
            id: UUID(),
            date: Date(),
            duration: 0, // Would calculate from session start
            averageScore: currentFormScore,
            sessions: [realTimeAnalysis],
            improvements: generateImprovementSuggestions(),
            strengths: generateStrengths()
        )
        
        analysisHistory.append(result)
    }
    
    private func generateImprovementSuggestions() -> [ImprovementSuggestion] {
        return [
            ImprovementSuggestion(
                area: "Turn Technique",
                description: "Practice sharper turns with better deceleration",
                exercises: ["Cone drills", "T-drill practice", "Deceleration training"],
                priority: .high
            ),
            ImprovementSuggestion(
                area: "Posture",
                description: "Maintain upright posture throughout the run",
                exercises: ["Core strengthening", "Posture awareness drills"],
                priority: .medium
            )
        ]
    }
    
    private func generateStrengths() -> [String] {
        return [
            "Consistent pace maintenance",
            "Good arm movement coordination",
            "Strong acceleration phase"
        ]
    }
    
    // MARK: - Analysis Utilities
    
    func getFormTrend(days: Int) -> [FormTrendPoint] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        // Filter analysis history for the specified period
        let filteredHistory = analysisHistory.filter { result in
            result.date >= startDate && result.date <= endDate
        }
        
        // Convert to trend points
        return filteredHistory.map { result in
            FormTrendPoint(
                date: result.date,
                score: result.averageScore,
                improvements: result.improvements.count
            )
        }
    }
    
    func getWeakestAspect() -> FormAspect? {
        return realTimeAnalysis?.aspects.min(by: { $0.score < $1.score })
    }
    
    func getStrongestAspect() -> FormAspect? {
        return realTimeAnalysis?.aspects.max(by: { $0.score < $1.score })
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension FormAnalysisManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Process video frames for real-time analysis
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // In a real implementation, you would process the pixel buffer with Vision
        processVideoFrame(pixelBuffer)
    }
    
    private func processVideoFrame(_ pixelBuffer: CVPixelBuffer) {
        // This would use Vision framework with your Core ML model
        // For demo purposes, we'll just trigger periodic analysis
        
        // Example Vision request (commented out for demo):
        /*
        guard let model = visionModel else { return }
        
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            if let results = request.results as? [VNClassificationObservation] {
                self?.processAnalysisResults(results)
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
        */
    }
    
    private func processAnalysisResults(_ results: [VNClassificationObservation]) {
        // Process the Core ML results and update form analysis
        // This would be implemented based on your specific model output
    }
}

// MARK: - Data Models

struct RealTimeAnalysis {
    let timestamp: Date
    let overallScore: Double
    let aspects: [FormAspect]
    let feedback: [FormFeedback]
    let keyPoints: [BodyKeyPoint]
}

struct FormAspect {
    let name: String
    let score: Double
    let ideal: String
    
    var scoreColor: Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        default: return .red
        }
    }
    
    var scoreText: String {
        switch score {
        case 0.9...1.0: return "Excellent"
        case 0.8..<0.9: return "Very Good"
        case 0.7..<0.8: return "Good"
        case 0.6..<0.7: return "Fair"
        default: return "Needs Work"
        }
    }
}

struct FormFeedback {
    let type: FeedbackType
    let message: String
    let suggestion: String
    let priority: Priority
    
    enum FeedbackType {
        case positive, improvement, warning, error
        
        var color: Color {
            switch self {
            case .positive: return .green
            case .improvement: return .blue
            case .warning: return .orange
            case .error: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .positive: return "checkmark.circle.fill"
            case .improvement: return "arrow.up.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
    }
    
    enum Priority {
        case low, medium, high
    }
}

struct BodyKeyPoint {
    let name: String
    let position: CGPoint
    let confidence: Double
}

struct FormAnalysisResult: Identifiable {
    let id: UUID
    let date: Date
    let duration: TimeInterval
    let averageScore: Double
    let sessions: [RealTimeAnalysis]
    let improvements: [ImprovementSuggestion]
    let strengths: [String]
}

struct ImprovementSuggestion {
    let area: String
    let description: String
    let exercises: [String]
    let priority: FormFeedback.Priority
}

struct FormTrendPoint {
    let date: Date
    let score: Double
    let improvements: Int
}

// MARK: - Extensions

extension Color {
    static func forScore(_ score: Double) -> Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }
}
