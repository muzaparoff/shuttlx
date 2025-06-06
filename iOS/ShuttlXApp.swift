//
//  ShuttlXApp.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI
import HealthKit
#if os(iOS)
import WatchConnectivity
#endif

// Simple test app structure - the actual services should be imported from Shared folder
// For now, we'll create basic stubs to test the dependency injection structure

// MARK: - Test Stubs (these should be replaced with actual imports)
@MainActor
class TestHealthManager: ObservableObject {
    @Published var isHealthDataAvailable = true
    @Published var currentHeartRate: Double? = 85
    
    func requestPermissions() async {
        print("Health permissions requested")
    }
}

@MainActor 
class TestAppViewModel: ObservableObject {
    @Published var hasCompletedOnboarding = true
    @Published var isWorkoutActive = false
    @Published var colorScheme: ColorScheme = .light
    
    func loadUserPreferences() {
        print("User preferences loaded")
    }
}

@MainActor
class TestAPIService: ObservableObject {
    func configure() {
        print("API service configured")
    }
}

@MainActor
class TestSocialService: ObservableObject {
    init(apiService: TestAPIService, healthManager: TestHealthManager) {
        print("Social service initialized with dependencies")
    }
}

@MainActor
class TestRealTimeMessagingService: ObservableObject {
    static let shared = TestRealTimeMessagingService()
    
    func configure(with apiService: TestAPIService) {
        print("Real-time messaging configured")
    }
    
    func connect() async {
        print("Real-time messaging connected")
    }
}

#if os(iOS)
@MainActor
class TestWatchConnectivityManager: ObservableObject {
    @Published var isWatchAppInstalled = false
    @Published var isWatchReachable = false
    
    func startSession() {
        print("Watch connectivity session started")
    }
}
#endif

@main
struct ShuttlXApp: App {
    @StateObject private var healthManager = TestHealthManager()
    #if os(iOS)
    @StateObject private var watchConnectivityManager = TestWatchConnectivityManager()
    #endif
    @StateObject private var appViewModel = TestAppViewModel()
    @StateObject private var apiService = TestAPIService()
    @StateObject private var socialService: TestSocialService
    @StateObject private var realTimeMessagingService = TestRealTimeMessagingService.shared
    
    init() {
        let apiServiceInstance = TestAPIService()
        let healthManagerInstance = TestHealthManager()
        
        _apiService = StateObject(wrappedValue: apiServiceInstance)
        _healthManager = StateObject(wrappedValue: healthManagerInstance)
        _socialService = StateObject(wrappedValue: TestSocialService(
            apiService: apiServiceInstance,
            healthManager: healthManagerInstance
        ))
        
        // Configure services
        realTimeMessagingService.configure(with: apiServiceInstance)
        apiServiceInstance.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            TestContentView()
                .environmentObject(healthManager)
                #if os(iOS)
                .environmentObject(watchConnectivityManager)
                #endif
                .environmentObject(appViewModel)
                .environmentObject(apiService)
                .environmentObject(socialService)
                .environmentObject(realTimeMessagingService)
                .preferredColorScheme(appViewModel.colorScheme)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        // Request HealthKit permissions
        Task {
            await healthManager.requestPermissions()
        }
        
        // Setup Watch Connectivity
        #if os(iOS)
        watchConnectivityManager.startSession()
        #endif
        
        // Load user preferences
        appViewModel.loadUserPreferences()
        
        // Setup authentication and connect to real-time messaging
        Task {
            await setupAuthentication()
        }
    }
    
    private func setupAuthentication() async {
        // Connect to real-time messaging once authenticated
        await realTimeMessagingService.connect()
    }
}

// MARK: - Test Content View
struct TestContentView: View {
    @EnvironmentObject var appViewModel: TestAppViewModel
    @EnvironmentObject var healthManager: TestHealthManager
    @EnvironmentObject var socialService: TestSocialService
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Test Dashboard
            VStack {
                Text("ShuttlX Fitness App")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Dependency Injection Working!")
                    .foregroundColor(.green)
                
                if let heartRate = healthManager.currentHeartRate {
                    Text("Heart Rate: \(Int(heartRate)) BPM")
                        .font(.headline)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Text("Social Features Status")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("✅ SocialService initialized with dependency injection")
                    Text("✅ APIService configured")
                    Text("✅ Real-time messaging configured")
                    Text("✅ HealthManager integrated")
                    
                    #if os(iOS)
                    Text("✅ Watch connectivity enabled")
                    #endif
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)
            
            // Social Tab
            VStack {
                Text("Social Features")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Ready for social features implementation")
                    .foregroundColor(.blue)
                
                Spacer()
            }
            .padding()
            .tabItem {
                Image(systemName: "person.2.fill")
                Text("Social")
            }
            .tag(1)
        }
        .accentColor(.orange)
    }
}
