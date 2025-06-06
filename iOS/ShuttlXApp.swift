//
//  ShuttlXApp.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI
import HealthKit
import WatchConnectivity

@main
struct ShuttlXApp: App {
    @StateObject private var healthManager = HealthManager()
    @StateObject private var watchConnectivityManager = WatchConnectivityManager()
    @StateObject private var appViewModel = AppViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthManager)
                .environmentObject(watchConnectivityManager)
                .environmentObject(appViewModel)
                .preferredColorScheme(appViewModel.colorScheme)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        // Request HealthKit permissions
        healthManager.requestPermissions()
        
        // Setup Watch Connectivity
        watchConnectivityManager.startSession()
        
        // Load user preferences
        appViewModel.loadUserPreferences()
    }
}
