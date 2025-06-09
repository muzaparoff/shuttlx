//
//  ServiceLocator.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/7/25.
//

import Foundation

class ServiceLocator: ObservableObject {
    static let shared = ServiceLocator()
    
    // Core MVP Services
    let healthManager = SimpleHealthManager()
    let watchManager = SimpleWatchManager()
    let settingsService = SettingsService()
    let notificationService = NotificationService()
    
    private init() {}
}
