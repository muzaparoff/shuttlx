//
//  SocialService.swift
//  ShuttlX MVP
//
//  Minimal social service for MVP compatibility
//  Created by ShuttlX on 6/9/25.
//

import Foundation

// MARK: - Minimal Social Service for MVP

class SocialService: ObservableObject {
    @Published var currentUserProfile: SocialUserProfile?
    @Published var isConnected: Bool = false
    
    init() {
        // Initialize with basic profile for MVP
        self.currentUserProfile = SocialUserProfile.default
    }
    
    func connect() async {
        // Placeholder for future social features
        self.isConnected = false
    }
    
    func disconnect() {
        self.isConnected = false
        self.currentUserProfile = SocialUserProfile.default
    }
}

// MARK: - Basic Social User Profile

struct SocialUserProfile: Codable {
    let id: UUID = UUID()
    var displayName: String
    var username: String
    var avatarURL: String?
    var isPrivate: Bool = true
    
    static let `default` = SocialUserProfile(
        displayName: "Runner",
        username: "runner",
        avatarURL: nil,
        isPrivate: true
    )
}
