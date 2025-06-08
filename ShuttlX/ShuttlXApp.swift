//
//  ShuttlXApp.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

@main
struct ShuttlXApp: App {
    @StateObject private var serviceLocator = ServiceLocator.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serviceLocator)
                .onAppear {
                    print("🚀 ShuttlX App launched with ServiceLocator")
                }
        }
    }
}
