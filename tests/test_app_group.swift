#!/usr/bin/env swift

import Foundation

// Test script to verify App Group container accessibility
let appGroupIdentifier = "group.com.shuttlx.shared"

print("Testing App Group container accessibility...")
print("App Group ID: \(appGroupIdentifier)")

// Helper function to test container accessibility
func testContainer(at url: URL, name: String) -> Bool {
    print("\n--- Testing \(name) ---")
    print("Container URL: \(url)")
    
    // Check if directory exists
    let fileManager = FileManager.default
    var isDirectory: ObjCBool = false
    
    if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue {
        print("✅ Directory exists")
    } else {
        print("⚠️ Directory doesn't exist, attempting to create...")
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            print("✅ Successfully created directory")
        } catch {
            print("❌ Failed to create directory: \(error)")
            return false
        }
    }
    
    // Test file operations
    let testFileURL = url.appendingPathComponent("test.txt")
    let testData = "Hello, \(name)!".data(using: .utf8)!
    
    do {
        try testData.write(to: testFileURL)
        print("✅ Successfully wrote test file")
        
        // Try to read it back
        let readData = try Data(contentsOf: testFileURL)
        let readString = String(data: readData, encoding: .utf8) ?? ""
        print("✅ Successfully read test file: '\(readString)'")
        
        // Clean up
        try fileManager.removeItem(at: testFileURL)
        print("✅ Cleaned up test file")
        
        return true
        
    } catch {
        print("❌ Failed file operations: \(error)")
        return false
    }
}

// Test App Group container
var appGroupWorking = false
if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
    appGroupWorking = testContainer(at: containerURL, name: "App Group Container")
} else {
    print("❌ App Group container URL is nil")
}

// Test fallback container
let fallbackContainer = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("SharedData")
let fallbackWorking = testContainer(at: fallbackContainer, name: "Fallback Container")

print("\n--- SUMMARY ---")
print("App Group Container: \(appGroupWorking ? "✅ Working" : "❌ Not Working")")
print("Fallback Container: \(fallbackWorking ? "✅ Working" : "❌ Not Working")")

if !appGroupWorking && fallbackWorking {
    print("\n✅ Fallback mechanism will work correctly")
    print("The SharedDataManager will automatically use the fallback container")
} else if appGroupWorking {
    print("\n✅ App Group container is functional")
} else {
    print("\n❌ Both containers failed - this indicates a serious filesystem issue")
}
