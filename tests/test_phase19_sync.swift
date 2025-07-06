#!/usr/bin/env swift

import Foundation

// Test script for Phase 19 - Live Sync Testing
// This script creates a test training program and verifies it appears in the App Group container

struct TrainingInterval: Codable {
    let duration: Int
    let intensity: String
    let type: String
}

struct TrainingProgram: Codable {
    let id: String
    let name: String
    let description: String
    let intervals: [TrainingInterval]
    let totalDuration: Int
    let programType: String
    let createdAt: Date
}

func createTestProgram() -> TrainingProgram {
    let intervals = [
        TrainingInterval(duration: 300, intensity: "Moderate", type: "Warm-up"),
        TrainingInterval(duration: 600, intensity: "High", type: "Main Set"),
        TrainingInterval(duration: 180, intensity: "Low", type: "Recovery"),
        TrainingInterval(duration: 600, intensity: "High", type: "Main Set"),
        TrainingInterval(duration: 300, intensity: "Low", type: "Cool-down")
    ]
    
    return TrainingProgram(
        id: "PHASE19_TEST_\(Int(Date().timeIntervalSince1970))",
        name: "Phase 19 Sync Test Program",
        description: "Test program created during Phase 19 live testing to verify iOS-watchOS sync functionality",
        intervals: intervals,
        totalDuration: intervals.reduce(0) { $0 + $1.duration },
        programType: "HIIT",
        createdAt: Date()
    )
}

func saveToAppGroup(_ program: TrainingProgram) -> Bool {
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.shuttlx.shared") else {
        print("❌ Failed to access App Group container")
        return false
    }
    
    let programsURL = containerURL.appendingPathComponent("programs")
    
    // Create directory if it doesn't exist
    do {
        try FileManager.default.createDirectory(at: programsURL, withIntermediateDirectories: true, attributes: nil)
    } catch {
        print("❌ Failed to create programs directory: \(error)")
        return false
    }
    
    let fileURL = programsURL.appendingPathComponent("\(program.id).json")
    
    do {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(program)
        try data.write(to: fileURL)
        print("✅ Program saved to: \(fileURL.path)")
        return true
    } catch {
        print("❌ Failed to save program: \(error)")
        return false
    }
}

func listExistingPrograms() {
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.shuttlx.shared") else {
        print("❌ Failed to access App Group container")
        return
    }
    
    let programsURL = containerURL.appendingPathComponent("programs")
    
    do {
        let files = try FileManager.default.contentsOfDirectory(at: programsURL, includingPropertiesForKeys: nil)
        print("\n📋 Existing programs in App Group container:")
        if files.isEmpty {
            print("   (No programs found)")
        } else {
            for file in files where file.pathExtension == "json" {
                print("   - \(file.lastPathComponent)")
            }
        }
    } catch {
        print("❌ Failed to list programs: \(error)")
    }
}

// Main execution
print("🧪 Phase 19 Live Sync Testing")
print("==============================")
print("App Group: group.shuttlx.shared")
print("Test: Creating training program and verifying App Group storage\n")

// List existing programs first
listExistingPrograms()

// Create and save test program
let testProgram = createTestProgram()
print("\n🎯 Creating test program:")
print("   Name: \(testProgram.name)")
print("   ID: \(testProgram.id)")
print("   Type: \(testProgram.programType)")
print("   Duration: \(testProgram.totalDuration) seconds")
print("   Intervals: \(testProgram.intervals.count)")

if saveToAppGroup(testProgram) {
    print("\n✅ Test program created successfully!")
    print("📱 Check iOS app: Program should appear in the main list")
    print("⌚ Check watchOS app: Program should sync within 30 seconds")
    print("🔍 Check DebugView on watchOS for sync status")
} else {
    print("\n❌ Failed to create test program")
}

// List programs after creation
listExistingPrograms()

print("\n🔄 Next steps:")
print("1. Open iOS ShuttlX app and verify the program appears")
print("2. Open watchOS ShuttlX app and check DebugView")
print("3. Wait for automatic sync (30-second interval)")
print("4. Verify program appears on watchOS")
