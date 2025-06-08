//
//  MLModelManager.swift
//  ShuttlX
//
//  Machine Learning model management for shuttle run form analysis (iOS Compatible)
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import CoreML
import Vision
import Combine

/// Manages machine learning models for shuttle run form analysis and performance prediction
@MainActor
class MLModelManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isModelLoading = false
    @Published var modelAccuracy: Double = 0.0
    @Published var availableModels: [MLModelInfo] = []
    @Published var activeModel: MLModelInfo?
    
    // MARK: - Private Properties
    private let modelStorageURL: URL
    
    // MARK: - Initialization
    init() {
        // Set up model storage location
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.modelStorageURL = documentsPath.appendingPathComponent("MLModels")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: modelStorageURL, withIntermediateDirectories: true)
        
        // Load available models
        loadAvailableModels()
    }
    
    // MARK: - Model Loading and Management
    
    /// Load a pre-trained model from the app bundle or documents directory
    func loadModel(named modelName: String) async throws -> MLModel {
        isModelLoading = true
        defer { isModelLoading = false }
        
        // First try to load from bundle
        if let bundleURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodel") {
            let compiledURL = try MLModel.compileModel(at: bundleURL)
            return try MLModel(contentsOf: compiledURL)
        }
        
        // Then try from documents directory
        let documentURL = modelStorageURL.appendingPathComponent("\(modelName).mlmodel")
        if FileManager.default.fileExists(atPath: documentURL.path) {
            let compiledURL = try MLModel.compileModel(at: documentURL)
            return try MLModel(contentsOf: compiledURL)
        }
        
        throw MLModelError.modelNotFound
    }
    
    /// Perform form analysis prediction using the active model
    func predictFormAnalysis(features: [String: Double]) async throws -> FormAnalysisPrediction {
        guard let activeModel = activeModel else {
            throw MLModelError.noActiveModel
        }
        
        let model = try await loadModel(named: activeModel.name)
        
        // Convert features to MLFeatureProvider
        let input = try MLDictionaryFeatureProvider(dictionary: features)
        let prediction = try model.prediction(from: input)
        
        // Extract prediction results
        let formScore = prediction.featureValue(for: "formScore")?.doubleValue ?? 0.0
        let recommendations = extractRecommendations(from: prediction)
        
        return FormAnalysisPrediction(
            formScore: formScore,
            recommendations: recommendations,
            confidence: prediction.featureValue(for: "confidence")?.doubleValue ?? 0.0
        )
    }
    
    /// Perform performance prediction using the active model
    func predictPerformance(features: [String: Double]) async throws -> PerformancePrediction {
        guard let activeModel = activeModel else {
            throw MLModelError.noActiveModel
        }
        
        let model = try await loadModel(named: activeModel.name)
        
        // Convert features to MLFeatureProvider
        let input = try MLDictionaryFeatureProvider(dictionary: features)
        let prediction = try model.prediction(from: input)
        
        // Extract prediction results
        let predictedTime = prediction.featureValue(for: "predictedTime")?.doubleValue ?? 0.0
        let performanceCategory = prediction.featureValue(for: "category")?.stringValue ?? "unknown"
        
        return PerformancePrediction(
            predictedTime: predictedTime,
            category: PerformanceCategory(rawValue: performanceCategory) ?? .unknown,
            confidence: prediction.featureValue(for: "confidence")?.doubleValue ?? 0.0
        )
    }
    
    // MARK: - Vision Framework Integration
    
    /// Process video frame for pose detection and feature extraction
    func processFrameForPoseDetection(pixelBuffer: CVPixelBuffer) async throws -> [String: Double] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectHumanBodyPoseRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNHumanBodyPoseObservation],
                      let observation = observations.first else {
                    continuation.resume(returning: [:])
                    return
                }
                
                do {
                    let features = try self.extractFeaturesFromPose(observation)
                    continuation.resume(returning: features)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadAvailableModels() {
        var models: [MLModelInfo] = []
        
        // Load models from bundle
        if let bundleModels = Bundle.main.urls(forResourcesWithExtension: "mlmodel", subdirectory: nil) {
            for url in bundleModels {
                let name = url.deletingPathExtension().lastPathComponent
                models.append(MLModelInfo(
                    id: UUID(),
                    name: name,
                    type: inferModelType(from: name),
                    accuracy: 0.85, // Default placeholder
                    dateCreated: Date(),
                    fileSize: 0
                ))
            }
        }
        
        // Load models from documents directory
        do {
            let documentModels = try FileManager.default.contentsOfDirectory(at: modelStorageURL, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            for url in documentModels.filter({ $0.pathExtension == "mlmodel" }) {
                let name = url.deletingPathExtension().lastPathComponent
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                
                models.append(MLModelInfo(
                    id: UUID(),
                    name: name,
                    type: inferModelType(from: name),
                    accuracy: 0.85, // Would be loaded from metadata in real implementation
                    dateCreated: attributes[.creationDate] as? Date ?? Date(),
                    fileSize: Int64(attributes[.size] as? UInt64 ?? 0)
                ))
            }
        } catch {
            print("Error loading models from documents: \(error)")
        }
        
        self.availableModels = models
        
        // Set first model as active if none is set
        if activeModel == nil, let firstModel = models.first {
            activeModel = firstModel
        }
    }
    
    private func inferModelType(from name: String) -> MLModelType {
        if name.lowercased().contains("form") {
            return .formAnalysis
        } else if name.lowercased().contains("performance") {
            return .performancePrediction
        }
        return .formAnalysis
    }
    
    private func extractRecommendations(from prediction: MLFeatureValue) -> [String] {
        // Extract recommendations from prediction output
        // This would be customized based on your specific model output format
        return [
            "Focus on arm swing timing",
            "Improve stride consistency",
            "Work on core stability"
        ]
    }
    
    private func extractFeaturesFromPose(_ observation: VNHumanBodyPoseObservation) throws -> [String: Double] {
        var features: [String: Double] = [:]
        
        // Extract key joint positions
        guard let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
              let rightShoulder = try? observation.recognizedPoint(.rightShoulder),
              let leftElbow = try? observation.recognizedPoint(.leftElbow),
              let rightElbow = try? observation.recognizedPoint(.rightElbow),
              let leftHip = try? observation.recognizedPoint(.leftHip),
              let rightHip = try? observation.recognizedPoint(.rightHip),
              let leftKnee = try? observation.recognizedPoint(.leftKnee),
              let rightKnee = try? observation.recognizedPoint(.rightKnee),
              let leftAnkle = try? observation.recognizedPoint(.leftAnkle),
              let rightAnkle = try? observation.recognizedPoint(.rightAnkle) else {
            throw MLModelError.poseDetectionFailed
        }
        
        // Calculate basic biomechanical features
        features["left_arm_angle"] = calculateAngle(leftShoulder.location, leftElbow.location, leftHip.location)
        features["right_arm_angle"] = calculateAngle(rightShoulder.location, rightElbow.location, rightHip.location)
        features["left_leg_angle"] = calculateAngle(leftHip.location, leftKnee.location, leftAnkle.location)
        features["right_leg_angle"] = calculateAngle(rightHip.location, rightKnee.location, rightAnkle.location)
        features["trunk_angle"] = calculateTrunkAngle(leftShoulder.location, rightShoulder.location, leftHip.location, rightHip.location)
        features["stride_width"] = abs(leftAnkle.location.x - rightAnkle.location.x)
        
        return features
    }
    
    private func calculateAngle(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) -> Double {
        let v1 = CGVector(dx: p1.x - p2.x, dy: p1.y - p2.y)
        let v2 = CGVector(dx: p3.x - p2.x, dy: p3.y - p2.y)
        
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let mag1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
        let mag2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)
        
        guard mag1 > 0 && mag2 > 0 else { return 0 }
        
        let cosAngle = dot / (mag1 * mag2)
        return acos(max(-1, min(1, cosAngle))) * 180 / .pi
    }
    
    private func calculateTrunkAngle(_ leftShoulder: CGPoint, _ rightShoulder: CGPoint, _ leftHip: CGPoint, _ rightHip: CGPoint) -> Double {
        let shoulderMidpoint = CGPoint(x: (leftShoulder.x + rightShoulder.x) / 2, y: (leftShoulder.y + rightShoulder.y) / 2)
        let hipMidpoint = CGPoint(x: (leftHip.x + rightHip.x) / 2, y: (leftHip.y + rightHip.y) / 2)
        
        let trunkVector = CGVector(dx: shoulderMidpoint.x - hipMidpoint.x, dy: shoulderMidpoint.y - hipMidpoint.y)
        let verticalVector = CGVector(dx: 0, dy: 1)
        
        let dot = trunkVector.dx * verticalVector.dx + trunkVector.dy * verticalVector.dy
        let mag = sqrt(trunkVector.dx * trunkVector.dx + trunkVector.dy * trunkVector.dy)
        
        guard mag > 0 else { return 0 }
        
        let cosAngle = dot / mag
        return acos(max(-1, min(1, cosAngle))) * 180 / .pi
    }
}

// MARK: - Supporting Types

enum MLModelError: Error {
    case modelNotFound
    case noActiveModel
    case poseDetectionFailed
    case predictionFailed
}

struct MLModelInfo: Identifiable, Equatable {
    let id: UUID
    let name: String
    let type: MLModelType
    let accuracy: Double
    let dateCreated: Date
    let fileSize: Int64
}

enum MLModelType {
    case formAnalysis
    case performancePrediction
}

struct FormAnalysisPrediction {
    let formScore: Double
    let recommendations: [String]
    let confidence: Double
}

struct PerformancePrediction {
    let predictedTime: Double
    let category: PerformanceCategory
    let confidence: Double
}

enum PerformanceCategory: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case average = "average"
    case needsImprovement = "needs_improvement"
    case unknown = "unknown"
}
