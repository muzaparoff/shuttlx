//
//  ServiceLocator.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/7/25.
//

import Foundation
import HealthKit
import CloudKit

// Service locator pattern to manage all our services with dependency injection
@MainActor
class ServiceLocator: ObservableObject {
    static let shared = ServiceLocator()
    
    // Core Services Status
    @Published var isInitialized = false
    @Published var servicesLoaded: [String] = []
    @Published var initializationErrors: [String] = []
    
    // Service instances
    private(set) var apiService: APIService!
    private(set) var healthManager: HealthManager!
    private(set) var cloudKitManager: CloudKitManager!
    private(set) var socialService: SocialService!
    private(set) var messagingService: MessagingService!
    private(set) var notificationService: NotificationService!
    private(set) var settingsService: SettingsService!
    private(set) var gamificationManager: GamificationManager!
    private(set) var hapticFeedbackManager: HapticFeedbackManager!
    private(set) var watchConnectivityManager: WatchConnectivityManager!
    private(set) var realTimeMessagingService: RealTimeMessagingService!
    
    private init() {
        setupServices()
    }
    
    private func setupServices() {
        Task {
            await initializeServices()
        }
    }
    
    private func initializeServices() async {
        do {
            // Initialize core services first
            healthManager = HealthManager()
            await recordServiceInitialization("HealthManager")
            
            cloudKitManager = CloudKitManager.shared
            await recordServiceInitialization("CloudKitManager")
            
            apiService = APIService.shared
            await recordServiceInitialization("APIService")
            
            // Initialize services that depend on core services
            socialService = SocialService(apiService: apiService, healthManager: healthManager)
            await recordServiceInitialization("SocialService")
            
            messagingService = MessagingService.shared
            await recordServiceInitialization("MessagingService")
            
            realTimeMessagingService = RealTimeMessagingService.shared
            await recordServiceInitialization("RealTimeMessagingService")
            
            notificationService = NotificationService.shared
            await recordServiceInitialization("NotificationService")
            
            settingsService = SettingsService.shared
            await recordServiceInitialization("SettingsService")
            
            gamificationManager = GamificationManager.shared
            await recordServiceInitialization("GamificationManager")
            
            hapticFeedbackManager = HapticFeedbackManager.shared
            await recordServiceInitialization("HapticFeedbackManager")
            
            watchConnectivityManager = WatchConnectivityManager()
            await recordServiceInitialization("WatchConnectivityManager")
            
            // Configure services that need dependencies
            gamificationManager.configure(socialService: socialService)
            
            // Request HealthKit permissions
            await healthManager.requestPermissions()
            
            isInitialized = true
            print("✅ ServiceLocator: All services initialized successfully")
            
        } catch {
            await recordServiceError("Failed to initialize services: \(error.localizedDescription)")
            print("❌ ServiceLocator initialization failed: \(error)")
        }
    }
    
    private func recordServiceInitialization(_ serviceName: String) async {
        await MainActor.run {
            servicesLoaded.append(serviceName)
            print("✅ \(serviceName) initialized")
        }
    }
    
    private func recordServiceError(_ error: String) async {
        await MainActor.run {
            initializationErrors.append(error)
            print("❌ ServiceLocator error: \(error)")
        }
    }
    
    
    // Service status methods
    func getServiceStatus() -> String {
        let loadedCount = servicesLoaded.count
        let errorCount = initializationErrors.count
        
        if errorCount > 0 {
            return "⚠️ \(loadedCount) services ready, \(errorCount) errors"
        } else {
            return "✅ \(loadedCount) services ready"
        }
    }
    
    func getAvailableServices() -> [String] {
        return servicesLoaded
    }
    
    func getInitializationErrors() -> [String] {
        return initializationErrors
    }
    
    // Service access methods
    func getAPIService() -> APIService {
        return apiService
    }
    
    func getHealthManager() -> HealthManager {
        return healthManager
    }
    
    func getCloudKitManager() -> CloudKitManager {
        return cloudKitManager
    }
    
    func getSocialService() -> SocialService {
        return socialService
    }
    
    func getMessagingService() -> MessagingService {
        return messagingService
    }
    
    func getNotificationService() -> NotificationService {
        return notificationService
    }
    
    func getSettingsService() -> SettingsService {
        return settingsService
    }
    
    func getGamificationManager() -> GamificationManager {
        return gamificationManager
    }
    
    func getHapticFeedbackManager() -> HapticFeedbackManager {
        return hapticFeedbackManager
    }
    
    func getWatchConnectivityManager() -> WatchConnectivityManager {
        return watchConnectivityManager
    }
    
    func getRealTimeMessagingService() -> RealTimeMessagingService {
        return realTimeMessagingService
    }
}
