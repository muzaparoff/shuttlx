#!/usr/bin/env swift

import Foundation

// Test script to debug sync issues
func testSharedContainer() {
    let identifier = "group.com.shuttlx.shared"
    
    print("🔍 Testing App Group shared container...")
    print("App Group Identifier: \(identifier)")
    
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
        print("❌ Failed to access shared container")
        return
    }
    
    print("✅ Container URL: \(containerURL.path)")
    
    let programsURL = containerURL.appendingPathComponent("programs.json")
    let sessionsURL = containerURL.appendingPathComponent("sessions.json")
    
    print("\n📱 Checking iOS programs file...")
    print("Programs file path: \(programsURL.path)")
    
    if FileManager.default.fileExists(atPath: programsURL.path) {
        do {
            let data = try Data(contentsOf: programsURL)
            print("✅ Programs file exists, size: \(data.count) bytes")
            let jsonString = String(data: data, encoding: .utf8) ?? "Invalid UTF-8"
            print("Raw JSON: \(jsonString.prefix(200))...")
        } catch {
            print("❌ Failed to read programs file: \(error)")
        }
    } else {
        print("❌ Programs file does not exist")
    }
    
    print("\n⌚ Checking watchOS sessions file...")
    print("Sessions file path: \(sessionsURL.path)")
    
    if FileManager.default.fileExists(atPath: sessionsURL.path) {
        do {
            let data = try Data(contentsOf: sessionsURL)
            print("✅ Sessions file exists, size: \(data.count) bytes")
        } catch {
            print("❌ Failed to read sessions file: \(error)")
        }
    } else {
        print("❌ Sessions file does not exist")
    }
    
    // List all files in container
    print("\n📂 All files in container:")
    do {
        let contents = try FileManager.default.contentsOfDirectory(at: containerURL, includingPropertiesForKeys: nil)
        for fileURL in contents {
            print("  - \(fileURL.lastPathComponent)")
        }
    } catch {
        print("❌ Failed to list container contents: \(error)")
    }
}

testSharedContainer()
