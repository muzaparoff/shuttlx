//
//  AIFormAnalysisService.swift
//  ShuttlX
//
//  AI-powered form analysis service using Core ML and Vision
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import CoreML
import Vision
import AVFoundation
import Combine
import UIKit
import CoreLocation

/// AI-powered form analysis service for real-time shuttle run form evaluation
@MainActor
class AIFormAnalysisService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAnalyzing = false
    @Published var isModelReady = false
    @Published var currentFormScore: Double = 0.0
    @Published var realTimeMetrics: FormMetrics?
    @Published var analysisResults: [FormAnalysisSession] = []
    @Published var bodyPoseDetected = false
    @Published var confidenceLevel: Double = 0.0
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var poseDetectionModel: VNCoreMLModel?
    private var formEvaluationModel: VNCoreMLModel?
    private var currentSession: FormAnalysisSession?
    private var frameBuffer: [CVPixelBuffer] = []
    private var bodyPoseHistory: [BodyPoseKeypoints] = []
    private var analysisTimer: Timer?
    private var sessionStartTime: Date?
    
    // Camera and processing
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "ai.form.analysis.session")
    private let processingQueue = DispatchQueue(label: "ai.form.analysis.processing", qos: .userInitiated)
    
    // Configuration
    private let maxFrameBufferSize = 30 // ~1 second at 30fps
    private let analysisInterval: TimeInterval = 0.5 // Analyze every 0.5 seconds
    private let minConfidenceThreshold: Double = 0.6
    
    override init() {
        super.init()
        setupModels()
        setupCameraSession()
        setupNotifications()
    }
    
    deinit {
        stopAnalysis()
        captureSession.stopRunning()
    }
}

// MARK: - Model Setup
extension AIFormAnalysisService {
    
    private func setupModels() {
        Task {
            await loadPoseDetectionModel()
            await loadFormEvaluationModel()
            await MainActor.run {
                self.isModelReady = self.poseDetectionModel != nil
            }
        }
    }
    
    private func loadPoseDetectionModel() async {
        do {
            // Try to load Apple's built-in human body pose detection model
            if #available(iOS 14.0, *) {
                // Use Vision's built-in body pose detection
                print("Using Vision's built-in human body pose detection")
                return
            }
            
            // Fallback: Load custom pose detection model if available
            guard let modelURL = Bundle.main.url(forResource: "HumanPoseDetection", withExtension: "mlmodelc") else {
                print("Custom pose detection model not found, using fallback")
                return
            }
            
            let model = try MLModel(contentsOf: modelURL)
            self.poseDetectionModel = try VNCoreMLModel(for: model)
            print("Custom pose detection model loaded successfully")
            
        } catch {
            print("Failed to load pose detection model: \(error)")
        }
    }
    
    private func loadFormEvaluationModel() async {
        do {
            guard let modelURL = Bundle.main.url(forResource: "ShuttleRunFormEvaluation", withExtension: "mlmodelc") else {
                print("Form evaluation model not found, using heuristic analysis")
                return
            }
            
            let model = try MLModel(contentsOf: modelURL)
            self.formEvaluationModel = try VNCoreMLModel(for: model)
            print("Form evaluation model loaded successfully")
            
        } catch {
            print("Failed to load form evaluation model: \(error)")
        }
    }
}

// MARK: - Camera Setup
extension AIFormAnalysisService {
    
    private func setupCameraSession() {
        captureSession.sessionPreset = .high
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoDeviceInput) else {
            print("Failed to setup camera for AI form analysis")
            return
        }
        
        captureSession.addInput(videoDeviceInput)
        
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // Configure frame rate for optimal performance
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.pauseAnalysis()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                if self?.isAnalyzing == true {
                    self?.resumeAnalysis()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Analysis Control
extension AIFormAnalysisService {
    
    func startAnalysis() async {
        guard isModelReady else {
            print("Models not ready for analysis")
            return
        }
        
        guard !isAnalyzing else { return }
        
        await MainActor.run {
            self.isAnalyzing = true
            self.sessionStartTime = Date()
            self.currentSession = FormAnalysisSession(
                id: UUID(),
                startTime: Date(),
                workoutType: .shuttleRun
            )
        }
        
        // Start camera session
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
        
        // Start periodic analysis
        startPeriodicAnalysis()
        
        print("AI form analysis started")
    }
    
    func stopAnalysis() {
        guard isAnalyzing else { return }
        
        isAnalyzing = false
        analysisTimer?.invalidate()
        analysisTimer = nil
        
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
        
        // Save current session
        if let session = currentSession {
            saveAnalysisSession(session)
        }
        
        // Clear buffers
        frameBuffer.removeAll()
        bodyPoseHistory.removeAll()
        currentSession = nil
        
        print("AI form analysis stopped")
    }
    
    private func pauseAnalysis() {
        if isAnalyzing {
            sessionQueue.async { [weak self] in
                self?.captureSession.stopRunning()
            }
            analysisTimer?.invalidate()
        }
    }
    
    private func resumeAnalysis() {
        if isAnalyzing {
            sessionQueue.async { [weak self] in
                self?.captureSession.startRunning()
            }
            startPeriodicAnalysis()
        }
    }
    
    private func startPeriodicAnalysis() {
        analysisTimer = Timer.scheduledTimer(withTimeInterval: analysisInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performFormAnalysis()
            }
        }
    }
}

// MARK: - Form Analysis Processing
extension AIFormAnalysisService {
    
    private func performFormAnalysis() async {
        guard !frameBuffer.isEmpty && !bodyPoseHistory.isEmpty else { return }
        
        // Get latest pose data
        let recentPoses = Array(bodyPoseHistory.suffix(10))
        
        // Perform heuristic analysis (will be replaced by ML model)
        let metrics = await analyzeFormHeuristically(poses: recentPoses)
        
        await MainActor.run {
            self.realTimeMetrics = metrics
            self.currentFormScore = metrics.overallScore
            self.confidenceLevel = metrics.confidence
            
            // Update current session
            self.currentSession?.addMetrics(metrics)
        }
    }
    
    private func analyzeFormHeuristically(poses: [BodyPoseKeypoints]) -> FormMetrics {
        guard !poses.isEmpty else {
            return FormMetrics.empty
        }
        
        let latestPose = poses.last!
        
        // Analyze various form aspects
        let postureScore = analyzePosture(pose: latestPose)
        let strideScore = analyzeStride(poses: poses)
        let armMovementScore = analyzeArmMovement(poses: poses)
        let footStrikeScore = analyzeFootStrike(pose: latestPose)
        let balanceScore = analyzeBalance(pose: latestPose)
        let turnTechniqueScore = analyzeTurnTechnique(poses: poses)
        
        let overallScore = (postureScore + strideScore + armMovementScore + 
                          footStrikeScore + balanceScore + turnTechniqueScore) / 6.0
        
        return FormMetrics(
            timestamp: Date(),
            overallScore: overallScore,
            confidence: latestPose.confidence,
            postureScore: postureScore,
            strideScore: strideScore,
            armMovementScore: armMovementScore,
            footStrikeScore: footStrikeScore,
            balanceScore: balanceScore,
            turnTechniqueScore: turnTechniqueScore,
            bodyKeypoints: latestPose,
            recommendations: generateRecommendations(
                posture: postureScore,
                stride: strideScore,
                armMovement: armMovementScore,
                footStrike: footStrikeScore,
                balance: balanceScore,
                turnTechnique: turnTechniqueScore
            )
        )
    }
    
    // MARK: - Individual Form Analysis Methods
    
    private func analyzePosture(pose: BodyPoseKeypoints) -> Double {
        guard let head = pose.head,
              let neck = pose.neck,
              let torso = pose.torso else { return 0.5 }
        
        // Calculate spine alignment
        let headNeckAngle = calculateAngle(point1: head.position, point2: neck.position, point3: torso.position)
        let idealAngle: Double = 180.0 // Straight spine
        let angleDifference = abs(headNeckAngle - idealAngle)
        
        // Score based on how close to ideal posture
        let score = max(0.0, 1.0 - (angleDifference / 45.0)) // Allow 45 degree deviation
        return min(1.0, score)
    }
    
    private func analyzeStride(poses: [BodyPoseKeypoints]) -> Double {
        guard poses.count >= 3 else { return 0.5 }
        
        var strideConsistency: [Double] = []
        
        for i in 1..<poses.count {
            guard let currentLeftKnee = poses[i].leftKnee,
                  let currentRightKnee = poses[i].rightKnee,
                  let previousLeftKnee = poses[i-1].leftKnee,
                  let previousRightKnee = poses[i-1].rightKnee else { continue }
            
            // Calculate knee lift consistency
            let leftKneeMovement = distance(currentLeftKnee.position, previousLeftKnee.position)
            let rightKneeMovement = distance(currentRightKnee.position, previousRightKnee.position)
            
            let consistency = 1.0 - abs(leftKneeMovement - rightKneeMovement) / max(leftKneeMovement, rightKneeMovement)
            strideConsistency.append(consistency)
        }
        
        return strideConsistency.isEmpty ? 0.5 : strideConsistency.reduce(0, +) / Double(strideConsistency.count)
    }
    
    private func analyzeArmMovement(poses: [BodyPoseKeypoints]) -> Double {
        guard poses.count >= 2 else { return 0.5 }
        
        let latest = poses.last!
        let previous = poses[poses.count - 2]
        
        guard let currentLeftElbow = latest.leftElbow,
              let currentRightElbow = latest.rightElbow,
              let previousLeftElbow = previous.leftElbow,
              let previousRightElbow = previous.rightElbow else { return 0.5 }
        
        // Calculate arm swing consistency
        let leftArmMovement = distance(currentLeftElbow.position, previousLeftElbow.position)
        let rightArmMovement = distance(currentRightElbow.position, previousRightElbow.position)
        
        // Good arm movement should be rhythmic and balanced
        let armBalance = 1.0 - abs(leftArmMovement - rightArmMovement) / max(leftArmMovement, rightArmMovement)
        
        return armBalance
    }
    
    private func analyzeFootStrike(pose: BodyPoseKeypoints) -> Double {
        guard let leftAnkle = pose.leftAnkle,
              let rightAnkle = pose.rightAnkle,
              let leftKnee = pose.leftKnee,
              let rightKnee = pose.rightKnee else { return 0.5 }
        
        // Analyze foot positioning relative to knee
        let leftFootKneeAlignment = abs(leftAnkle.position.x - leftKnee.position.x)
        let rightFootKneeAlignment = abs(rightAnkle.position.x - rightKnee.position.x)
        
        // Good foot strike should have feet landing under knees
        let leftScore = max(0.0, 1.0 - leftFootKneeAlignment * 5.0) // Adjust multiplier as needed
        let rightScore = max(0.0, 1.0 - rightFootKneeAlignment * 5.0)
        
        return (leftScore + rightScore) / 2.0
    }
    
    private func analyzeBalance(pose: BodyPoseKeypoints) -> Double {
        guard let leftAnkle = pose.leftAnkle,
              let rightAnkle = pose.rightAnkle,
              let torso = pose.torso else { return 0.5 }
        
        // Calculate center of mass relative to feet
        let centerOfFeet = CGPoint(
            x: (leftAnkle.position.x + rightAnkle.position.x) / 2.0,
            y: (leftAnkle.position.y + rightAnkle.position.y) / 2.0
        )
        
        let balanceOffset = distance(torso.position, centerOfFeet)
        
        // Good balance means torso is centered over feet
        return max(0.0, 1.0 - balanceOffset * 3.0) // Adjust multiplier as needed
    }
    
    private func analyzeTurnTechnique(poses: [BodyPoseKeypoints]) -> Double {
        guard poses.count >= 5 else { return 0.5 }
        
        // Detect turning motion by analyzing direction changes
        var directionChanges: [Double] = []
        
        for i in 2..<poses.count {
            guard let current = poses[i].torso?.position,
                  let previous = poses[i-1].torso?.position,
                  let beforePrevious = poses[i-2].torso?.position else { continue }
            
            let angle1 = atan2(previous.y - beforePrevious.y, previous.x - beforePrevious.x)
            let angle2 = atan2(current.y - previous.y, current.x - previous.x)
            
            let angleDifference = abs(angle2 - angle1)
            directionChanges.append(angleDifference)
        }
        
        // Good turns should be smooth and controlled
        if directionChanges.isEmpty {
            return 0.5
        }
        
        let averageChange = directionChanges.reduce(0, +) / Double(directionChanges.count)
        
        // Score based on smoothness (less sudden changes = better)
        return max(0.0, 1.0 - averageChange)
    }
    
    private func generateRecommendations(
        posture: Double,
        stride: Double,
        armMovement: Double,
        footStrike: Double,
        balance: Double,
        turnTechnique: Double
    ) -> [FormRecommendation] {
        var recommendations: [FormRecommendation] = []
        
        if posture < 0.7 {
            recommendations.append(FormRecommendation(
                type: .posture,
                message: "Keep your back straight and head up",
                priority: .high,
                exercises: ["Wall slides", "Posture holds", "Core strengthening"]
            ))
        }
        
        if stride < 0.7 {
            recommendations.append(FormRecommendation(
                type: .stride,
                message: "Focus on consistent stride length",
                priority: .medium,
                exercises: ["High knees", "Butt kicks", "A-skips"]
            ))
        }
        
        if armMovement < 0.7 {
            recommendations.append(FormRecommendation(
                type: .armMovement,
                message: "Pump your arms rhythmically",
                priority: .medium,
                exercises: ["Arm swings", "Running drills", "Metronome training"]
            ))
        }
        
        if footStrike < 0.7 {
            recommendations.append(FormRecommendation(
                type: .footStrike,
                message: "Land on forefoot, not heel",
                priority: .high,
                exercises: ["Barefoot running", "Calf raises", "Forefoot drills"]
            ))
        }
        
        if balance < 0.7 {
            recommendations.append(FormRecommendation(
                type: .balance,
                message: "Keep your core engaged for better balance",
                priority: .medium,
                exercises: ["Single-leg stands", "Plank holds", "Balance board training"]
            ))
        }
        
        if turnTechnique < 0.7 {
            recommendations.append(FormRecommendation(
                type: .turnTechnique,
                message: "Practice controlled deceleration and acceleration",
                priority: .high,
                exercises: ["Cone drills", "T-drill", "Agility ladder"]
            ))
        }
        
        return recommendations
    }
}

// MARK: - Utility Functions
extension AIFormAnalysisService {
    
    private func calculateAngle(point1: CGPoint, point2: CGPoint, point3: CGPoint) -> Double {
        let vector1 = CGPoint(x: point1.x - point2.x, y: point1.y - point2.y)
        let vector2 = CGPoint(x: point3.x - point2.x, y: point3.y - point2.y)
        
        let dotProduct = vector1.x * vector2.x + vector1.y * vector2.y
        let magnitude1 = sqrt(vector1.x * vector1.x + vector1.y * vector1.y)
        let magnitude2 = sqrt(vector2.x * vector2.x + vector2.y * vector2.y)
        
        let cosAngle = dotProduct / (magnitude1 * magnitude2)
        let angleRadians = acos(max(-1.0, min(1.0, cosAngle)))
        return angleRadians * 180.0 / .pi
    }
    
    private func distance(_ point1: CGPoint, _ point2: CGPoint) -> Double {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(Double(dx * dx + dy * dy))
    }
    
    private func saveAnalysisSession(_ session: FormAnalysisSession) {
        var completedSession = session
        completedSession.endTime = Date()
        
        if let startTime = sessionStartTime {
            completedSession.duration = Date().timeIntervalSince(startTime)
        }
        
        analysisResults.append(completedSession)
        
        // Keep only last 50 sessions to manage memory
        if analysisResults.count > 50 {
            analysisResults.removeFirst(analysisResults.count - 50)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension AIFormAnalysisService: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Manage frame buffer size
        if frameBuffer.count >= maxFrameBufferSize {
            frameBuffer.removeFirst()
        }
        frameBuffer.append(pixelBuffer)
        
        // Process frame for pose detection
        processingQueue.async { [weak self] in
            self?.detectBodyPose(in: pixelBuffer)
        }
    }
    
    private func detectBodyPose(in pixelBuffer: CVPixelBuffer) {
        if #available(iOS 14.0, *) {
            detectBodyPoseWithVision(pixelBuffer)
        } else {
            // Fallback for older iOS versions
            generateMockPoseData()
        }
    }
    
    @available(iOS 14.0, *)
    private func detectBodyPoseWithVision(_ pixelBuffer: CVPixelBuffer) {
        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Body pose detection error: \(error)")
                return
            }
            
            guard let observations = request.results as? [VNHumanBodyPoseObservation],
                  let bodyPose = observations.first else {
                DispatchQueue.main.async {
                    self.bodyPoseDetected = false
                }
                return
            }
            
            // Convert Vision results to our format
            let keypoints = self.convertVisionPoseToKeypoints(bodyPose)
            
            DispatchQueue.main.async {
                self.bodyPoseDetected = true
                
                // Manage pose history
                if self.bodyPoseHistory.count >= 30 { // Keep last 30 poses
                    self.bodyPoseHistory.removeFirst()
                }
                self.bodyPoseHistory.append(keypoints)
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform body pose detection: \(error)")
        }
    }
    
    @available(iOS 14.0, *)
    private func convertVisionPoseToKeypoints(_ observation: VNHumanBodyPoseObservation) -> BodyPoseKeypoints {
        func getKeypoint(_ jointName: VNHumanBodyPoseObservation.JointName) -> KeypointData? {
            guard let point = try? observation.recognizedPoint(jointName),
                  point.confidence > Float(minConfidenceThreshold) else { return nil }
            
            return KeypointData(
                position: CGPoint(x: CGFloat(point.location.x), y: CGFloat(1.0 - point.location.y)), // Flip Y coordinate
                confidence: Double(point.confidence)
            )
        }
        
        let allKeypoints = [
            getKeypoint(.nose),
            getKeypoint(.neck),
            getKeypoint(.rightShoulder),
            getKeypoint(.leftShoulder),
            getKeypoint(.rightElbow),
            getKeypoint(.leftElbow),
            getKeypoint(.rightWrist),
            getKeypoint(.leftWrist),
            getKeypoint(.rightHip),
            getKeypoint(.leftHip),
            getKeypoint(.rightKnee),
            getKeypoint(.leftKnee),
            getKeypoint(.rightAnkle),
            getKeypoint(.leftAnkle)
        ].compactMap { $0 }
        
        let averageConfidence = allKeypoints.isEmpty ? 0.0 : allKeypoints.map { $0.confidence }.reduce(0, +) / Double(allKeypoints.count)
        
        return BodyPoseKeypoints(
            head: getKeypoint(.nose),
            neck: getKeypoint(.neck),
            torso: calculateTorsoCenter(leftShoulder: getKeypoint(.leftShoulder), rightShoulder: getKeypoint(.rightShoulder), leftHip: getKeypoint(.leftHip), rightHip: getKeypoint(.rightHip)),
            leftShoulder: getKeypoint(.leftShoulder),
            rightShoulder: getKeypoint(.rightShoulder),
            leftElbow: getKeypoint(.leftElbow),
            rightElbow: getKeypoint(.rightElbow),
            leftWrist: getKeypoint(.leftWrist),
            rightWrist: getKeypoint(.rightWrist),
            leftHip: getKeypoint(.leftHip),
            rightHip: getKeypoint(.rightHip),
            leftKnee: getKeypoint(.leftKnee),
            rightKnee: getKeypoint(.rightKnee),
            leftAnkle: getKeypoint(.leftAnkle),
            rightAnkle: getKeypoint(.rightAnkle),
            confidence: averageConfidence
        )
    }
    
    private func calculateTorsoCenter(leftShoulder: KeypointData?, rightShoulder: KeypointData?, leftHip: KeypointData?, rightHip: KeypointData?) -> KeypointData? {
        guard let leftShoulder = leftShoulder,
              let rightShoulder = rightShoulder,
              let leftHip = leftHip,
              let rightHip = rightHip else { return nil }
        
        let centerX = (leftShoulder.position.x + rightShoulder.position.x + leftHip.position.x + rightHip.position.x) / 4.0
        let centerY = (leftShoulder.position.y + rightShoulder.position.y + leftHip.position.y + rightHip.position.y) / 4.0
        let averageConfidence = (leftShoulder.confidence + rightShoulder.confidence + leftHip.confidence + rightHip.confidence) / 4.0
        
        return KeypointData(
            position: CGPoint(x: centerX, y: centerY),
            confidence: averageConfidence
        )
    }
    
    private func generateMockPoseData() {
        // Fallback for demo or when actual pose detection fails
        let mockKeypoints = BodyPoseKeypoints(
            head: KeypointData(position: CGPoint(x: 0.5, y: 0.1), confidence: 0.9),
            neck: KeypointData(position: CGPoint(x: 0.5, y: 0.2), confidence: 0.85),
            torso: KeypointData(position: CGPoint(x: 0.5, y: 0.4), confidence: 0.9),
            leftShoulder: KeypointData(position: CGPoint(x: 0.4, y: 0.25), confidence: 0.8),
            rightShoulder: KeypointData(position: CGPoint(x: 0.6, y: 0.25), confidence: 0.8),
            leftElbow: KeypointData(position: CGPoint(x: 0.35, y: 0.4), confidence: 0.75),
            rightElbow: KeypointData(position: CGPoint(x: 0.65, y: 0.4), confidence: 0.75),
            leftWrist: KeypointData(position: CGPoint(x: 0.3, y: 0.55), confidence: 0.7),
            rightWrist: KeypointData(position: CGPoint(x: 0.7, y: 0.55), confidence: 0.7),
            leftHip: KeypointData(position: CGPoint(x: 0.45, y: 0.55), confidence: 0.85),
            rightHip: KeypointData(position: CGPoint(x: 0.55, y: 0.55), confidence: 0.85),
            leftKnee: KeypointData(position: CGPoint(x: 0.42, y: 0.75), confidence: 0.8),
            rightKnee: KeypointData(position: CGPoint(x: 0.58, y: 0.75), confidence: 0.8),
            leftAnkle: KeypointData(position: CGPoint(x: 0.4, y: 0.95), confidence: 0.85),
            rightAnkle: KeypointData(position: CGPoint(x: 0.6, y: 0.95), confidence: 0.85),
            confidence: 0.8
        )
        
        DispatchQueue.main.async {
            self.bodyPoseDetected = true
            
            if self.bodyPoseHistory.count >= 30 {
                self.bodyPoseHistory.removeFirst()
            }
            self.bodyPoseHistory.append(mockKeypoints)
        }
    }
}

// MARK: - Data Models

struct FormMetrics {
    let timestamp: Date
    let overallScore: Double
    let confidence: Double
    let postureScore: Double
    let strideScore: Double
    let armMovementScore: Double
    let footStrikeScore: Double
    let balanceScore: Double
    let turnTechniqueScore: Double
    let bodyKeypoints: BodyPoseKeypoints
    let recommendations: [FormRecommendation]
    
    static let empty = FormMetrics(
        timestamp: Date(),
        overallScore: 0.0,
        confidence: 0.0,
        postureScore: 0.0,
        strideScore: 0.0,
        armMovementScore: 0.0,
        footStrikeScore: 0.0,
        balanceScore: 0.0,
        turnTechniqueScore: 0.0,
        bodyKeypoints: BodyPoseKeypoints.empty,
        recommendations: []
    )
}

struct BodyPoseKeypoints {
    let head: KeypointData?
    let neck: KeypointData?
    let torso: KeypointData?
    let leftShoulder: KeypointData?
    let rightShoulder: KeypointData?
    let leftElbow: KeypointData?
    let rightElbow: KeypointData?
    let leftWrist: KeypointData?
    let rightWrist: KeypointData?
    let leftHip: KeypointData?
    let rightHip: KeypointData?
    let leftKnee: KeypointData?
    let rightKnee: KeypointData?
    let leftAnkle: KeypointData?
    let rightAnkle: KeypointData?
    let confidence: Double
    
    static let empty = BodyPoseKeypoints(
        head: nil, neck: nil, torso: nil,
        leftShoulder: nil, rightShoulder: nil,
        leftElbow: nil, rightElbow: nil,
        leftWrist: nil, rightWrist: nil,
        leftHip: nil, rightHip: nil,
        leftKnee: nil, rightKnee: nil,
        leftAnkle: nil, rightAnkle: nil,
        confidence: 0.0
    )
}

struct KeypointData {
    let position: CGPoint
    let confidence: Double
}

struct FormRecommendation {
    let type: RecommendationType
    let message: String
    let priority: Priority
    let exercises: [String]
    
    enum RecommendationType {
        case posture, stride, armMovement, footStrike, balance, turnTechnique
        
        var icon: String {
            switch self {
            case .posture: return "figure.stand"
            case .stride: return "figure.walk"
            case .armMovement: return "hands.clap"
            case .footStrike: return "shoe"
            case .balance: return "scale.3d"
            case .turnTechnique: return "arrow.uturn.left"
            }
        }
    }
    
    enum Priority {
        case low, medium, high
        
        var color: String {
            switch self {
            case .low: return "green"
            case .medium: return "yellow"
            case .high: return "red"
            }
        }
    }
}

struct FormAnalysisSession {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval = 0
    let workoutType: WorkoutType
    private(set) var metricsHistory: [FormMetrics] = []
    
    enum WorkoutType {
        case shuttleRun, hiit, running, custom
    }
    
    mutating func addMetrics(_ metrics: FormMetrics) {
        metricsHistory.append(metrics)
        
        // Keep only last 100 metrics to manage memory
        if metricsHistory.count > 100 {
            metricsHistory.removeFirst(metricsHistory.count - 100)
        }
    }
    
    var averageFormScore: Double {
        guard !metricsHistory.isEmpty else { return 0.0 }
        return metricsHistory.map { $0.overallScore }.reduce(0, +) / Double(metricsHistory.count)
    }
    
    var averageConfidence: Double {
        guard !metricsHistory.isEmpty else { return 0.0 }
        return metricsHistory.map { $0.confidence }.reduce(0, +) / Double(metricsHistory.count)
    }
    
    var topRecommendations: [FormRecommendation] {
        let allRecommendations = metricsHistory.flatMap { $0.recommendations }
        let groupedByType = Dictionary(grouping: allRecommendations) { $0.type }
        
        return groupedByType.compactMap { (type, recommendations) in
            // Return the highest priority recommendation for each type
            recommendations.max { $0.priority.rawValue < $1.priority.rawValue }
        }.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
}

// MARK: - Priority Extension
extension FormRecommendation.Priority: Comparable {
    var rawValue: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }
    
    static func < (lhs: FormRecommendation.Priority, rhs: FormRecommendation.Priority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
