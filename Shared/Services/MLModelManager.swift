//
//  MLModelManager.swift
//  ShuttlX
//
//  Machine Learning model management and training for shuttle run form analysis
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import CoreML
import Vision
import CreateML
import TabularData
import Combine

/// Manages machine learning models for shuttle run form analysis and performance prediction
@MainActor
class MLModelManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isTrainingInProgress = false
    @Published var trainingProgress: Double = 0.0
    @Published var modelAccuracy: Double = 0.0
    @Published var availableModels: [MLModelInfo] = []
    @Published var activeModel: MLModelInfo?
    
    // MARK: - Private Properties
    private var trainingCancellable: AnyCancellable?
    private let modelStorageURL: URL
    private let trainingDataURL: URL
    
    // Model configurations
    private let formAnalysisModelConfig = MLCreateMLConfig()
    private let performancePredictionConfig = MLCreateMLConfig()
    
    init() {
        // Setup storage URLs
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.modelStorageURL = documentsPath.appendingPathComponent("MLModels")
        self.trainingDataURL = documentsPath.appendingPathComponent("TrainingData")
        
        setupModelStorage()
        loadAvailableModels()
    }
}

// MARK: - Model Training
extension MLModelManager {
    
    /// Train a new shuttle run form analysis model using collected data
    func trainFormAnalysisModel(
        trainingData: [FormTrainingData],
        validationSplit: Double = 0.2,
        maxIterations: Int = 100
    ) async throws -> MLModelInfo {
        
        guard !isTrainingInProgress else {
            throw MLModelError.trainingInProgress
        }
        
        isTrainingInProgress = true
        trainingProgress = 0.0
        
        defer {
            isTrainingInProgress = false
            trainingProgress = 0.0
        }
        
        do {
            // Prepare training data
            let dataFrame = try await prepareFormAnalysisData(trainingData)
            
            // Update progress
            await MainActor.run { self.trainingProgress = 0.2 }
            
            // Split data
            let shuffledData = dataFrame.shuffled()
            let splitIndex = Int(Double(shuffledData.rows.count) * (1.0 - validationSplit))
            let trainingDataFrame = DataFrame(shuffledData.prefix(splitIndex))
            let validationDataFrame = DataFrame(shuffledData.suffix(from: splitIndex))
            
            // Update progress
            await MainActor.run { self.trainingProgress = 0.3 }
            
            // Configure training parameters
            var regressorConfig = MLBoostedTreeRegressor.ModelParameters()
            regressorConfig.maxIterations = maxIterations
            regressorConfig.validationData = validationDataFrame
            
            // Train the model
            let regressor = try MLBoostedTreeRegressor(
                trainingData: trainingDataFrame,
                targetColumn: "formScore",
                featureColumns: [
                    "postureAngle", "strideConsistency", "armSymmetry",
                    "footStrikePattern", "balanceScore", "turnSharpness",
                    "velocityVariation", "accelerationPattern"
                ],
                parameters: regressorConfig
            )
            
            // Update progress
            await MainActor.run { self.trainingProgress = 0.8 }
            
            // Evaluate model
            let evaluation = regressor.evaluation(on: validationDataFrame)
            let accuracy = 1.0 - evaluation.rootMeanSquaredError
            
            // Save model
            let modelInfo = try await saveModel(regressor, accuracy: accuracy, type: .formAnalysis)
            
            // Update progress
            await MainActor.run { 
                self.trainingProgress = 1.0
                self.modelAccuracy = accuracy
                self.availableModels.append(modelInfo)
            }
            
            return modelInfo
            
        } catch {
            await MainActor.run {
                self.isTrainingInProgress = false
                self.trainingProgress = 0.0
            }
            throw error
        }
    }
    
    /// Train a performance prediction model based on historical data
    func trainPerformancePredictionModel(
        trainingData: [PerformanceTrainingData],
        validationSplit: Double = 0.2,
        maxIterations: Int = 100
    ) async throws -> MLModelInfo {
        
        guard !isTrainingInProgress else {
            throw MLModelError.trainingInProgress
        }
        
        isTrainingInProgress = true
        trainingProgress = 0.0
        
        defer {
            isTrainingInProgress = false
            trainingProgress = 0.0
        }
        
        do {
            // Prepare training data
            let dataFrame = try await preparePerformanceData(trainingData)
            
            // Update progress
            await MainActor.run { self.trainingProgress = 0.2 }
            
            // Split data
            let shuffledData = dataFrame.shuffled()
            let splitIndex = Int(Double(shuffledData.rows.count) * (1.0 - validationSplit))
            let trainingDataFrame = DataFrame(shuffledData.prefix(splitIndex))
            let validationDataFrame = DataFrame(shuffledData.suffix(from: splitIndex))
            
            // Update progress
            await MainActor.run { self.trainingProgress = 0.3 }
            
            // Configure training parameters
            var classifierConfig = MLBoostedTreeClassifier.ModelParameters()
            classifierConfig.maxIterations = maxIterations
            classifierConfig.validationData = validationDataFrame
            
            // Train the model
            let classifier = try MLBoostedTreeClassifier(
                trainingData: trainingDataFrame,
                targetColumn: "performanceCategory",
                featureColumns: [
                    "averageFormScore", "heartRateVariability", "restingHeartRate",
                    "sleepQuality", "stressLevel", "workoutFrequency",
                    "recoveryScore", "nutritionScore", "hydrationLevel"
                ],
                parameters: classifierConfig
            )
            
            // Update progress
            await MainActor.run { self.trainingProgress = 0.8 }
            
            // Evaluate model
            let evaluation = classifier.evaluation(on: validationDataFrame)
            let accuracy = evaluation.classificationError
            
            // Save model
            let modelInfo = try await saveModel(classifier, accuracy: accuracy, type: .performancePrediction)
            
            // Update progress
            await MainActor.run { 
                self.trainingProgress = 1.0
                self.modelAccuracy = accuracy
                self.availableModels.append(modelInfo)
            }
            
            return modelInfo
            
        } catch {
            await MainActor.run {
                self.isTrainingInProgress = false
                self.trainingProgress = 0.0
            }
            throw error
        }
    }
    
    /// Train an injury risk assessment model
    func trainInjuryRiskModel(
        trainingData: [InjuryRiskTrainingData],
        validationSplit: Double = 0.2,
        maxIterations: Int = 100
    ) async throws -> MLModelInfo {
        
        guard !isTrainingInProgress else {
            throw MLModelError.trainingInProgress
        }
        
        isTrainingInProgress = true
        trainingProgress = 0.0
        
        defer {
            isTrainingInProgress = false
            trainingProgress = 0.0
        }
        
        do {
            // Prepare training data
            let dataFrame = try await prepareInjuryRiskData(trainingData)
            
            // Update progress
            await MainActor.run { self.trainingProgress = 0.2 }
            
            // Split data
            let shuffledData = dataFrame.shuffled()
            let splitIndex = Int(Double(shuffledData.rows.count) * (1.0 - validationSplit))
            let trainingDataFrame = DataFrame(shuffledData.prefix(splitIndex))
            let validationDataFrame = DataFrame(shuffledData.suffix(from: splitIndex))
            
            // Update progress
            await MainActor.run { self.trainingProgress = 0.3 }
            
            // Configure training parameters
            var classifierConfig = MLRandomForestClassifier.ModelParameters()
            classifierConfig.maxIterations = maxIterations
            classifierConfig.validationData = validationDataFrame
            
            // Train the model
            let classifier = try MLRandomForestClassifier(
                trainingData: trainingDataFrame,
                targetColumn: "injuryRisk",
                featureColumns: [
                    "formConsistency", "workoutIntensity", "recoveryTime",
                    "previousInjuries", "muscleFatigue", "jointStress",
                    "biomechanicalImbalance", "trainingLoad", "age", "experience"
                ],
                parameters: classifierConfig
            )
            
            // Update progress
            await MainActor.run { self.trainingProgress = 0.8 }
            
            // Evaluate model
            let evaluation = classifier.evaluation(on: validationDataFrame)
            let accuracy = 1.0 - evaluation.classificationError
            
            // Save model
            let modelInfo = try await saveModel(classifier, accuracy: accuracy, type: .injuryRisk)
            
            // Update progress
            await MainActor.run { 
                self.trainingProgress = 1.0
                self.modelAccuracy = accuracy
                self.availableModels.append(modelInfo)
            }
            
            return modelInfo
            
        } catch {
            await MainActor.run {
                self.isTrainingInProgress = false
                self.trainingProgress = 0.0
            }
            throw error
        }
    }
}

// MARK: - Data Preparation
extension MLModelManager {
    
    private func prepareFormAnalysisData(_ trainingData: [FormTrainingData]) async throws -> DataFrame {
        var data: [[String: Any]] = []
        
        for sample in trainingData {
            let row: [String: Any] = [
                "postureAngle": sample.postureAngle,
                "strideConsistency": sample.strideConsistency,
                "armSymmetry": sample.armSymmetry,
                "footStrikePattern": sample.footStrikePattern,
                "balanceScore": sample.balanceScore,
                "turnSharpness": sample.turnSharpness,
                "velocityVariation": sample.velocityVariation,
                "accelerationPattern": sample.accelerationPattern,
                "formScore": sample.expertFormScore
            ]
            data.append(row)
        }
        
        return try DataFrame(data)
    }
    
    private func preparePerformanceData(_ trainingData: [PerformanceTrainingData]) async throws -> DataFrame {
        var data: [[String: Any]] = []
        
        for sample in trainingData {
            let row: [String: Any] = [
                "averageFormScore": sample.averageFormScore,
                "heartRateVariability": sample.heartRateVariability,
                "restingHeartRate": sample.restingHeartRate,
                "sleepQuality": sample.sleepQuality,
                "stressLevel": sample.stressLevel,
                "workoutFrequency": sample.workoutFrequency,
                "recoveryScore": sample.recoveryScore,
                "nutritionScore": sample.nutritionScore,
                "hydrationLevel": sample.hydrationLevel,
                "performanceCategory": sample.performanceCategory.rawValue
            ]
            data.append(row)
        }
        
        return try DataFrame(data)
    }
    
    private func prepareInjuryRiskData(_ trainingData: [InjuryRiskTrainingData]) async throws -> DataFrame {
        var data: [[String: Any]] = []
        
        for sample in trainingData {
            let row: [String: Any] = [
                "formConsistency": sample.formConsistency,
                "workoutIntensity": sample.workoutIntensity,
                "recoveryTime": sample.recoveryTime,
                "previousInjuries": sample.previousInjuries,
                "muscleFatigue": sample.muscleFatigue,
                "jointStress": sample.jointStress,
                "biomechanicalImbalance": sample.biomechanicalImbalance,
                "trainingLoad": sample.trainingLoad,
                "age": sample.age,
                "experience": sample.experience,
                "injuryRisk": sample.injuryRisk.rawValue
            ]
            data.append(row)
        }
        
        return try DataFrame(data)
    }
}

// MARK: - Model Management
extension MLModelManager {
    
    private func setupModelStorage() {
        do {
            try FileManager.default.createDirectory(at: modelStorageURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: trainingDataURL, withIntermediateDirectories: true)
        } catch {
            print("Failed to create model storage directories: \(error)")
        }
    }
    
    private func loadAvailableModels() {
        do {
            let modelFiles = try FileManager.default.contentsOfDirectory(at: modelStorageURL, includingPropertiesForKeys: nil)
            
            for modelFile in modelFiles where modelFile.pathExtension == "mlmodelc" {
                if let modelInfo = loadModelInfo(from: modelFile) {
                    availableModels.append(modelInfo)
                }
            }
        } catch {
            print("Failed to load available models: \(error)")
        }
    }
    
    private func saveModel<T: MLWritable>(_ model: T, accuracy: Double, type: MLModelType) async throws -> MLModelInfo {
        let modelName = "\(type.rawValue)_\(Date().timeIntervalSince1970)"
        let modelURL = modelStorageURL.appendingPathComponent("\(modelName).mlmodelc")
        
        try await model.write(to: modelURL)
        
        let modelInfo = MLModelInfo(
            id: UUID(),
            name: modelName,
            type: type,
            accuracy: accuracy,
            createdDate: Date(),
            modelURL: modelURL,
            isActive: false
        )
        
        // Save model metadata
        try saveModelMetadata(modelInfo)
        
        return modelInfo
    }
    
    private func saveModelMetadata(_ modelInfo: MLModelInfo) throws {
        let metadataURL = modelStorageURL.appendingPathComponent("\(modelInfo.name)_metadata.json")
        let metadata = try JSONEncoder().encode(modelInfo)
        try metadata.write(to: metadataURL)
    }
    
    private func loadModelInfo(from modelURL: URL) -> MLModelInfo? {
        let metadataURL = modelStorageURL.appendingPathComponent("\(modelURL.deletingPathExtension().lastPathComponent)_metadata.json")
        
        guard let metadata = try? Data(contentsOf: metadataURL),
              let modelInfo = try? JSONDecoder().decode(MLModelInfo.self, from: metadata) else {
            return nil
        }
        
        return modelInfo
    }
    
    func activateModel(_ modelInfo: MLModelInfo) {
        // Deactivate current model
        if let currentActiveIndex = availableModels.firstIndex(where: { $0.isActive }) {
            availableModels[currentActiveIndex].isActive = false
        }
        
        // Activate new model
        if let modelIndex = availableModels.firstIndex(where: { $0.id == modelInfo.id }) {
            availableModels[modelIndex].isActive = true
            activeModel = availableModels[modelIndex]
        }
    }
    
    func deleteModel(_ modelInfo: MLModelInfo) throws {
        // Remove model file
        try FileManager.default.removeItem(at: modelInfo.modelURL)
        
        // Remove metadata file
        let metadataURL = modelStorageURL.appendingPathComponent("\(modelInfo.name)_metadata.json")
        try FileManager.default.removeItem(at: metadataURL)
        
        // Remove from available models
        availableModels.removeAll { $0.id == modelInfo.id }
        
        // Clear active model if deleted
        if activeModel?.id == modelInfo.id {
            activeModel = nil
        }
    }
}

// MARK: - Model Inference
extension MLModelManager {
    
    /// Predict form score using the active form analysis model
    func predictFormScore(features: FormAnalysisFeatures) async throws -> Double {
        guard let activeModel = activeModel,
              activeModel.type == .formAnalysis else {
            throw MLModelError.noActiveModel
        }
        
        let model = try MLModel(contentsOf: activeModel.modelURL)
        
        // Prepare input
        let input = try MLDictionaryFeatureProvider(dictionary: [
            "postureAngle": features.postureAngle,
            "strideConsistency": features.strideConsistency,
            "armSymmetry": features.armSymmetry,
            "footStrikePattern": features.footStrikePattern,
            "balanceScore": features.balanceScore,
            "turnSharpness": features.turnSharpness,
            "velocityVariation": features.velocityVariation,
            "accelerationPattern": features.accelerationPattern
        ])
        
        // Make prediction
        let output = try model.prediction(from: input)
        
        guard let formScore = output.featureValue(for: "formScore")?.doubleValue else {
            throw MLModelError.invalidPrediction
        }
        
        return formScore
    }
    
    /// Predict performance category using the active performance model
    func predictPerformance(features: PerformanceFeatures) async throws -> PerformanceCategory {
        guard let activeModel = activeModel,
              activeModel.type == .performancePrediction else {
            throw MLModelError.noActiveModel
        }
        
        let model = try MLModel(contentsOf: activeModel.modelURL)
        
        // Prepare input
        let input = try MLDictionaryFeatureProvider(dictionary: [
            "averageFormScore": features.averageFormScore,
            "heartRateVariability": features.heartRateVariability,
            "restingHeartRate": features.restingHeartRate,
            "sleepQuality": features.sleepQuality,
            "stressLevel": features.stressLevel,
            "workoutFrequency": features.workoutFrequency,
            "recoveryScore": features.recoveryScore,
            "nutritionScore": features.nutritionScore,
            "hydrationLevel": features.hydrationLevel
        ])
        
        // Make prediction
        let output = try model.prediction(from: input)
        
        guard let performanceCategoryString = output.featureValue(for: "performanceCategory")?.stringValue,
              let performanceCategory = PerformanceCategory(rawValue: performanceCategoryString) else {
            throw MLModelError.invalidPrediction
        }
        
        return performanceCategory
    }
    
    /// Predict injury risk using the active injury risk model
    func predictInjuryRisk(features: InjuryRiskFeatures) async throws -> InjuryRiskLevel {
        guard let activeModel = activeModel,
              activeModel.type == .injuryRisk else {
            throw MLModelError.noActiveModel
        }
        
        let model = try MLModel(contentsOf: activeModel.modelURL)
        
        // Prepare input
        let input = try MLDictionaryFeatureProvider(dictionary: [
            "formConsistency": features.formConsistency,
            "workoutIntensity": features.workoutIntensity,
            "recoveryTime": features.recoveryTime,
            "previousInjuries": features.previousInjuries,
            "muscleFatigue": features.muscleFatigue,
            "jointStress": features.jointStress,
            "biomechanicalImbalance": features.biomechanicalImbalance,
            "trainingLoad": features.trainingLoad,
            "age": features.age,
            "experience": features.experience
        ])
        
        // Make prediction
        let output = try model.prediction(from: input)
        
        guard let injuryRiskString = output.featureValue(for: "injuryRisk")?.stringValue,
              let injuryRisk = InjuryRiskLevel(rawValue: injuryRiskString) else {
            throw MLModelError.invalidPrediction
        }
        
        return injuryRisk
    }
}

// MARK: - Data Collection for Training
extension MLModelManager {
    
    /// Generate synthetic training data for initial model training
    func generateSyntheticFormData(count: Int = 1000) -> [FormTrainingData] {
        var data: [FormTrainingData] = []
        
        for _ in 0..<count {
            let postureAngle = Double.random(in: 160...180)
            let strideConsistency = Double.random(in: 0.6...0.95)
            let armSymmetry = Double.random(in: 0.7...0.95)
            let footStrikePattern = Double.random(in: 0.5...0.9)
            let balanceScore = Double.random(in: 0.6...0.95)
            let turnSharpness = Double.random(in: 0.5...0.9)
            let velocityVariation = Double.random(in: 0.1...0.4)
            let accelerationPattern = Double.random(in: 0.6...0.9)
            
            // Calculate expert form score based on weighted features
            let expertFormScore = (
                postureAngle / 180.0 * 0.2 +
                strideConsistency * 0.15 +
                armSymmetry * 0.1 +
                footStrikePattern * 0.15 +
                balanceScore * 0.15 +
                turnSharpness * 0.15 +
                (1.0 - velocityVariation) * 0.05 +
                accelerationPattern * 0.05
            )
            
            data.append(FormTrainingData(
                postureAngle: postureAngle,
                strideConsistency: strideConsistency,
                armSymmetry: armSymmetry,
                footStrikePattern: footStrikePattern,
                balanceScore: balanceScore,
                turnSharpness: turnSharpness,
                velocityVariation: velocityVariation,
                accelerationPattern: accelerationPattern,
                expertFormScore: expertFormScore
            ))
        }
        
        return data
    }
    
    /// Generate synthetic performance prediction data
    func generateSyntheticPerformanceData(count: Int = 1000) -> [PerformanceTrainingData] {
        var data: [PerformanceTrainingData] = []
        
        for _ in 0..<count {
            let averageFormScore = Double.random(in: 0.5...0.95)
            let heartRateVariability = Double.random(in: 20...60)
            let restingHeartRate = Double.random(in: 50...80)
            let sleepQuality = Double.random(in: 0.5...1.0)
            let stressLevel = Double.random(in: 0.1...0.8)
            let workoutFrequency = Double.random(in: 2...7)
            let recoveryScore = Double.random(in: 0.4...0.95)
            let nutritionScore = Double.random(in: 0.5...0.9)
            let hydrationLevel = Double.random(in: 0.6...1.0)
            
            // Determine performance category based on factors
            let performanceScore = averageFormScore * 0.3 + 
                                 recoveryScore * 0.2 + 
                                 (1.0 - stressLevel) * 0.15 + 
                                 sleepQuality * 0.15 + 
                                 nutritionScore * 0.1 + 
                                 hydrationLevel * 0.1
            
            let performanceCategory: PerformanceCategory
            switch performanceScore {
            case 0.8...1.0: performanceCategory = .excellent
            case 0.7..<0.8: performanceCategory = .good
            case 0.6..<0.7: performanceCategory = .average
            default: performanceCategory = .poor
            }
            
            data.append(PerformanceTrainingData(
                averageFormScore: averageFormScore,
                heartRateVariability: heartRateVariability,
                restingHeartRate: restingHeartRate,
                sleepQuality: sleepQuality,
                stressLevel: stressLevel,
                workoutFrequency: workoutFrequency,
                recoveryScore: recoveryScore,
                nutritionScore: nutritionScore,
                hydrationLevel: hydrationLevel,
                performanceCategory: performanceCategory
            ))
        }
        
        return data
    }
    
    /// Generate synthetic injury risk data
    func generateSyntheticInjuryRiskData(count: Int = 1000) -> [InjuryRiskTrainingData] {
        var data: [InjuryRiskTrainingData] = []
        
        for _ in 0..<count {
            let formConsistency = Double.random(in: 0.5...0.95)
            let workoutIntensity = Double.random(in: 0.3...1.0)
            let recoveryTime = Double.random(in: 6...48)
            let previousInjuries = Int.random(in: 0...5)
            let muscleFatigue = Double.random(in: 0.1...0.9)
            let jointStress = Double.random(in: 0.1...0.8)
            let biomechanicalImbalance = Double.random(in: 0.0...0.6)
            let trainingLoad = Double.random(in: 0.3...1.0)
            let age = Int.random(in: 18...65)
            let experience = Int.random(in: 0...20)
            
            // Calculate injury risk based on factors
            let riskScore = (1.0 - formConsistency) * 0.2 +
                           workoutIntensity * 0.15 +
                           (1.0 - min(recoveryTime / 24.0, 1.0)) * 0.15 +
                           min(Double(previousInjuries) / 3.0, 1.0) * 0.1 +
                           muscleFatigue * 0.15 +
                           jointStress * 0.1 +
                           biomechanicalImbalance * 0.1 +
                           trainingLoad * 0.05
            
            let injuryRisk: InjuryRiskLevel
            switch riskScore {
            case 0.7...1.0: injuryRisk = .high
            case 0.4..<0.7: injuryRisk = .moderate
            default: injuryRisk = .low
            }
            
            data.append(InjuryRiskTrainingData(
                formConsistency: formConsistency,
                workoutIntensity: workoutIntensity,
                recoveryTime: recoveryTime,
                previousInjuries: previousInjuries,
                muscleFatigue: muscleFatigue,
                jointStress: jointStress,
                biomechanicalImbalance: biomechanicalImbalance,
                trainingLoad: trainingLoad,
                age: age,
                experience: experience,
                injuryRisk: injuryRisk
            ))
        }
        
        return data
    }
}

// MARK: - Data Models

struct MLModelInfo: Codable, Identifiable {
    let id: UUID
    let name: String
    let type: MLModelType
    let accuracy: Double
    let createdDate: Date
    let modelURL: URL
    var isActive: Bool
    
    var displayName: String {
        return type.displayName + " (\(String(format: "%.1f%%", accuracy * 100)))"
    }
    
    var ageString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdDate, relativeTo: Date())
    }
}

enum MLModelType: String, Codable, CaseIterable {
    case formAnalysis = "form_analysis"
    case performancePrediction = "performance_prediction"
    case injuryRisk = "injury_risk"
    
    var displayName: String {
        switch self {
        case .formAnalysis: return "Form Analysis"
        case .performancePrediction: return "Performance Prediction"
        case .injuryRisk: return "Injury Risk Assessment"
        }
    }
    
    var icon: String {
        switch self {
        case .formAnalysis: return "figure.run"
        case .performancePrediction: return "chart.line.uptrend.xyaxis"
        case .injuryRisk: return "heart.text.square"
        }
    }
}

// MARK: - Training Data Models

struct FormTrainingData {
    let postureAngle: Double
    let strideConsistency: Double
    let armSymmetry: Double
    let footStrikePattern: Double
    let balanceScore: Double
    let turnSharpness: Double
    let velocityVariation: Double
    let accelerationPattern: Double
    let expertFormScore: Double
}

struct PerformanceTrainingData {
    let averageFormScore: Double
    let heartRateVariability: Double
    let restingHeartRate: Double
    let sleepQuality: Double
    let stressLevel: Double
    let workoutFrequency: Double
    let recoveryScore: Double
    let nutritionScore: Double
    let hydrationLevel: Double
    let performanceCategory: PerformanceCategory
}

struct InjuryRiskTrainingData {
    let formConsistency: Double
    let workoutIntensity: Double
    let recoveryTime: Double
    let previousInjuries: Int
    let muscleFatigue: Double
    let jointStress: Double
    let biomechanicalImbalance: Double
    let trainingLoad: Double
    let age: Int
    let experience: Int
    let injuryRisk: InjuryRiskLevel
}

// MARK: - Feature Models

struct FormAnalysisFeatures {
    let postureAngle: Double
    let strideConsistency: Double
    let armSymmetry: Double
    let footStrikePattern: Double
    let balanceScore: Double
    let turnSharpness: Double
    let velocityVariation: Double
    let accelerationPattern: Double
}

struct PerformanceFeatures {
    let averageFormScore: Double
    let heartRateVariability: Double
    let restingHeartRate: Double
    let sleepQuality: Double
    let stressLevel: Double
    let workoutFrequency: Double
    let recoveryScore: Double
    let nutritionScore: Double
    let hydrationLevel: Double
}

struct InjuryRiskFeatures {
    let formConsistency: Double
    let workoutIntensity: Double
    let recoveryTime: Double
    let previousInjuries: Int
    let muscleFatigue: Double
    let jointStress: Double
    let biomechanicalImbalance: Double
    let trainingLoad: Double
    let age: Int
    let experience: Int
}

// MARK: - Enums

enum PerformanceCategory: String, Codable, CaseIterable {
    case poor = "poor"
    case average = "average"
    case good = "good"
    case excellent = "excellent"
    
    var displayName: String {
        return rawValue.capitalized
    }
    
    var color: String {
        switch self {
        case .poor: return "red"
        case .average: return "yellow"
        case .good: return "blue"
        case .excellent: return "green"
        }
    }
}

enum InjuryRiskLevel: String, Codable, CaseIterable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    
    var displayName: String {
        return rawValue.capitalized
    }
    
    var color: String {
        switch self {
        case .low: return "green"
        case .moderate: return "yellow"
        case .high: return "red"
        }
    }
}

// MARK: - Errors

enum MLModelError: LocalizedError {
    case trainingInProgress
    case noActiveModel
    case invalidPrediction
    case modelNotFound
    case invalidTrainingData
    
    var errorDescription: String? {
        switch self {
        case .trainingInProgress:
            return "Model training is already in progress"
        case .noActiveModel:
            return "No active model available for prediction"
        case .invalidPrediction:
            return "Model returned invalid prediction"
        case .modelNotFound:
            return "Requested model not found"
        case .invalidTrainingData:
            return "Training data is invalid or insufficient"
        }
    }
}
