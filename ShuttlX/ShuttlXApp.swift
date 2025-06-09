//
//  ShuttlXApp.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI
import os.log

@main
struct ShuttlXApp: App {
    @StateObject private var serviceLocator = ServiceLocator.shared
    
    init() {
        print("🚀 [STARTUP] ShuttlX App initializing...")
        print("🚀 [STARTUP] Bundle ID: \(Bundle.main.bundleIdentifier ?? "UNKNOWN")")
        print("🚀 [STARTUP] App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "UNKNOWN")")
        print("🚀 [STARTUP] Build Number: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "UNKNOWN")")
        print("🚀 [STARTUP] Device: \(UIDevice.current.name)")
        print("🚀 [STARTUP] iOS Version: \(UIDevice.current.systemVersion)")
        print("🚀 [STARTUP] ServiceLocator initializing...")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serviceLocator)
                .onAppear {
                    print("🚀 [STARTUP] ContentView appeared successfully")
                    print("🚀 [STARTUP] ServiceLocator status: \(serviceLocator.description)")
                    print("🚀 [STARTUP] App fully loaded and ready!")
                }
        }
    }
}
