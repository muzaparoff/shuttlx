#!/usr/bin/env swift

import Foundation
import WatchConnectivity

// Create a test for Watch Connectivity
print("🔗 Testing WatchConnectivity Session")
print("==================================")

// Check if WatchConnectivity is supported
if WCSession.isSupported() {
    print("✅ WatchConnectivity is supported")
    
    let session = WCSession.default
    print("📱 Session state: \(session.activationState.rawValue)")
    print("📞 Is reachable: \(session.isReachable)")
    print("📲 Is iPhone paired: \(session.isPaired)")
    print("⌚ Is watch app installed: \(session.isWatchAppInstalled)")
    
    // Test sending a message if connected
    if session.isReachable {
        print("🚀 Attempting to send test message...")
        session.sendMessage(["test": "sync"], replyHandler: { reply in
            print("✅ Received reply: \(reply)")
        }, errorHandler: { error in
            print("❌ Error sending message: \(error.localizedDescription)")
        })
    } else {
        print("⚠️  Watch is not reachable for immediate communication")
        print("💾 Data will sync via App Group container")
    }
} else {
    print("❌ WatchConnectivity is not supported on this platform")
}

// Test App Group container access from iOS perspective
print("\n📂 Testing App Group Container from iOS")
print("=====================================")

if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared") {
    print("✅ App Group container accessible: \(containerURL.path)")
    
    let programsURL = containerURL.appendingPathComponent("programs.json")
    if FileManager.default.fileExists(atPath: programsURL.path) {
        do {
            let data = try Data(contentsOf: programsURL)
            let programs = try JSONDecoder().decode([String: Any].self, from: data)
            print("✅ Successfully loaded programs from App Group")
            print("📊 Number of programs: \(programs.count)")
        } catch {
            print("❌ Error loading programs: \(error.localizedDescription)")
        }
    } else {
        print("⚠️  programs.json not found in App Group container")
    }
} else {
    print("❌ Cannot access App Group container")
}

print("\n🔧 Sync test complete!")
print("💡 Check the DebugView on the watch app to see real-time sync status")
