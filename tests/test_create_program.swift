#!/usr/bin/env swift
import Foundation

// Test script to create a sample training program in the App Group container

let appGroupIdentifier = "group.com.shuttlx.shared"
let programsKey = "programs.json"

// Create a test training program
struct TrainingInterval: Codable, Identifiable {
    let id = UUID()
    let phase: Phase
    let duration: TimeInterval // in seconds
    let intensity: Intensity
    
    enum Phase: String, CaseIterable, Codable {
        case warmup = "Warmup"
        case work = "Work"
        case rest = "Rest"
        case cooldown = "Cooldown"
    }
    
    enum Intensity: String, CaseIterable, Codable {
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
        case maximum = "Maximum"
    }
}

struct TrainingProgram: Codable, Identifiable {
    let id = UUID()
    let name: String
    let type: ProgramType
    let intervals: [TrainingInterval]
    let maxPulse: Int
    let createdDate: Date
    let lastModified: Date
    
    enum ProgramType: String, CaseIterable, Codable {
        case walkRun = "Walk/Run"
        case cycling = "Cycling"
        case hiit = "HIIT"
        case strength = "Strength"
        case custom = "Custom"
    }
    
    var totalDuration: TimeInterval {
        intervals.reduce(0) { $0 + $1.duration }
    }
}

// Create test program
let testProgram = TrainingProgram(
    name: "Test Sync Program",
    type: .walkRun,
    intervals: [
        TrainingInterval(phase: .warmup, duration: 300, intensity: .low),    // 5 min warmup
        TrainingInterval(phase: .work, duration: 120, intensity: .high),     // 2 min work
        TrainingInterval(phase: .rest, duration: 60, intensity: .low),       // 1 min rest
        TrainingInterval(phase: .work, duration: 120, intensity: .high),     // 2 min work
        TrainingInterval(phase: .rest, duration: 60, intensity: .low),       // 1 min rest
        TrainingInterval(phase: .cooldown, duration: 300, intensity: .low)   // 5 min cooldown
    ],
    maxPulse: 180,
    createdDate: Date(),
    lastModified: Date()
)

print("🔍 ShuttlX Test Program Creator")
print("==================================")

// Try to access App Group container
if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
    print("✅ App Group container accessible: \(containerURL)")
    
    let programsURL = containerURL.appendingPathComponent(programsKey)
    
    // Load existing programs or create empty array
    var programs: [TrainingProgram] = []
    
    if FileManager.default.fileExists(atPath: programsURL.path) {
        do {
            let data = try Data(contentsOf: programsURL)
            programs = try JSONDecoder().decode([TrainingProgram].self, from: data)
            print("📋 Loaded \(programs.count) existing programs")
        } catch {
            print("⚠️  Failed to load existing programs: \(error)")
        }
    } else {
        print("📄 No existing programs file found, starting fresh")
    }
    
    // Add the test program
    programs.append(testProgram)
    print("➕ Added test program: '\(testProgram.name)'")
    
    // Save programs back to container
    do {
        let data = try JSONEncoder().encode(programs)
        try data.write(to: programsURL)
        print("✅ Successfully saved \(programs.count) programs to App Group container")
        print("📁 Saved to: \(programsURL)")
        
        // Print program details
        print("\n📋 Test Program Details:")
        print("   Name: \(testProgram.name)")
        print("   Type: \(testProgram.type.rawValue)")
        print("   Duration: \(Int(testProgram.totalDuration/60)) minutes")
        print("   Intervals: \(testProgram.intervals.count)")
        print("   Max HR: \(testProgram.maxPulse) bpm")
        
    } catch {
        print("❌ Failed to save programs: \(error)")
    }
    
} else {
    print("❌ App Group container not accessible")
    print("ℹ️  This usually means the app group is not configured properly")
    
    // Try fallback directory
    let fallbackURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("SharedData")
    print("📂 Trying fallback directory: \(fallbackURL)")
    
    try! FileManager.default.createDirectory(at: fallbackURL, withIntermediateDirectories: true)
    let programsURL = fallbackURL.appendingPathComponent(programsKey)
    
    let programs = [testProgram]
    let data = try! JSONEncoder().encode(programs)
    try! data.write(to: programsURL)
    print("✅ Saved test program to fallback location")
}

print("\n🔧 Test Complete")
print("💡 Next steps:")
print("   1. Run the iOS and watchOS apps in simulators")
print("   2. Check if the test program appears in the watchOS app")
print("   3. Try the manual sync button on the watch if needed")
