#!/usr/bin/env swift

import Foundation

print("🔍 ShuttlX Comprehensive Sync Analysis")
print("=====================================")

// Test App Group container access
let appGroupIdentifier = "group.com.shuttlx.shared"
let fileManager = FileManager.default

print("\n📁 App Group Container Analysis:")
print("--------------------------------")

if let sharedContainer = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
    print("✅ App Group container accessible: \(sharedContainer.path)")
    
    // Check if directory exists
    var isDirectory: ObjCBool = false
    if fileManager.fileExists(atPath: sharedContainer.path, isDirectory: &isDirectory) && isDirectory.boolValue {
        print("✅ Container directory exists")
        
        // List contents
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: sharedContainer.path)
            print("📋 Container contents (\(contents.count) items):")
            for item in contents {
                let itemPath = sharedContainer.appendingPathComponent(item)
                let attributes = try? fileManager.attributesOfItem(atPath: itemPath.path)
                let size = attributes?[.size] as? Int64 ?? 0
                let modDate = attributes?[.modificationDate] as? Date ?? Date()
                print("  - \(item) (\(size) bytes, modified: \(DateFormatter.localizedString(from: modDate, dateStyle: .short, timeStyle: .short)))")
            }
        } catch {
            print("❌ Could not list container contents: \(error)")
        }
        
        // Check specific files
        let programsFile = sharedContainer.appendingPathComponent("programs.json")
        let sessionsFile = sharedContainer.appendingPathComponent("sessions.json")
        
        print("\n📄 Critical Files Analysis:")
        print("---------------------------")
        
        // Programs file
        if fileManager.fileExists(atPath: programsFile.path) {
            do {
                let data = try Data(contentsOf: programsFile)
                print("✅ programs.json exists (\(data.count) bytes)")
                
                // Try to decode as JSON
                if let programs = try? JSONDecoder().decode([TrainingProgram].self, from: data) {
                    print("✅ programs.json is valid JSON with \(programs.count) programs:")
                    for (index, program) in programs.enumerated() {
                        print("  \(index + 1). \(program.name) (\(program.intervals.count) intervals, \(Int(program.totalDuration/60)) min)")
                    }
                } else {
                    print("❌ programs.json is not valid TrainingProgram JSON")
                    // Try basic JSON parsing
                    if let json = try? JSONSerialization.jsonObject(with: data) {
                        print("⚠️  File contains JSON but not in expected format")
                    } else {
                        print("❌ File is not valid JSON at all")
                    }
                }
            } catch {
                print("❌ Could not read programs.json: \(error)")
            }
        } else {
            print("❌ programs.json does not exist")
        }
        
        // Sessions file
        if fileManager.fileExists(atPath: sessionsFile.path) {
            do {
                let data = try Data(contentsOf: sessionsFile)
                print("✅ sessions.json exists (\(data.count) bytes)")
                
                if let sessions = try? JSONDecoder().decode([TrainingSession].self, from: data) {
                    print("✅ sessions.json is valid JSON with \(sessions.count) sessions")
                } else {
                    print("❌ sessions.json is not valid TrainingSession JSON")
                }
            } catch {
                print("❌ Could not read sessions.json: \(error)")
            }
        } else {
            print("❌ sessions.json does not exist")
        }
        
    } else {
        print("❌ Container directory does not exist")
    }
} else {
    print("❌ App Group container not accessible - check entitlements")
}

print("\n🧪 Creating Test Program for Sync Verification:")
print("------------------------------------------------")

// Create a comprehensive test program
let testProgram = TrainingProgram(
    name: "Comprehensive Sync Test \(Date().timeIntervalSince1970)",
    type: .walkRun,
    intervals: [
        TrainingInterval(phase: .warmup, duration: 300, intensity: .low),
        TrainingInterval(phase: .work, duration: 120, intensity: .high),
        TrainingInterval(phase: .rest, duration: 90, intensity: .low),
        TrainingInterval(phase: .work, duration: 180, intensity: .moderate),
        TrainingInterval(phase: .cooldown, duration: 300, intensity: .low)
    ],
    maxPulse: 180,
    createdDate: Date(),
    lastModified: Date()
)

print("✅ Test program created: \(testProgram.name)")
print("   Duration: \(Int(testProgram.totalDuration/60)) minutes")
print("   Intervals: \(testProgram.intervals.count)")

// Save test program to shared storage
if let sharedContainer = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
    let programsFile = sharedContainer.appendingPathComponent("programs.json")
    
    // Load existing programs
    var existingPrograms: [TrainingProgram] = []
    if fileManager.fileExists(atPath: programsFile.path) {
        do {
            let data = try Data(contentsOf: programsFile)
            existingPrograms = try JSONDecoder().decode([TrainingProgram].self, from: data)
            print("📋 Loaded \(existingPrograms.count) existing programs")
        } catch {
            print("⚠️  Could not load existing programs: \(error)")
        }
    }
    
    // Add test program
    existingPrograms.append(testProgram)
    
    // Save updated programs
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(existingPrograms)
        try data.write(to: programsFile)
        print("✅ Test program saved to shared storage")
        print("📊 Total programs now: \(existingPrograms.count)")
    } catch {
        print("❌ Failed to save test program: \(error)")
    }
}

print("\n🔧 Recommended Fixes for Sync Issues:")
print("=====================================")
print("1. DebugView UI Issues:")
print("   - Remove 'Test App Group' and 'Load Programs' buttons")
print("   - Programs should load automatically on view appearance")
print("   - Fix layout to prevent text overflow")
print("   - Add compact display for program list")

print("\n2. Sync Architecture Issues:")
print("   - watchOS should auto-load programs on startup")
print("   - iOS should immediately sync when programs are created/modified")
print("   - Use App Groups as primary storage, WatchConnectivity for real-time updates")
print("   - Implement proper error handling and retry logic")

print("\n3. Data Format:")
print("   - Programs are correctly stored as JSON files")
print("   - Each platform should verify JSON validity before using")
print("   - Implement data validation and corruption recovery")

print("\n4. Testing Strategy:")
print("   - Use Xcode simulators with proper pairing")
print("   - Create programs on iOS and verify they appear on watchOS")
print("   - Test sync when apps are backgrounded/foregrounded")
print("   - Verify App Group permissions in both simulators")

print("\n📱⌚ Next Steps:")
print("================")
print("1. Fix DebugView UI layout and remove unnecessary buttons")
print("2. Ensure automatic program loading on both platforms")
print("3. Test sync flow by creating programs on iOS")
print("4. Verify real-time updates via WatchConnectivity")
print("5. Document best practices for reliable sync")

// MARK: - Data Models (for compilation)

struct TrainingProgram: Codable, Identifiable {
    let id = UUID()
    let name: String
    let type: ProgramType
    let intervals: [TrainingInterval]
    let maxPulse: Int
    let createdDate: Date
    let lastModified: Date
    
    var totalDuration: TimeInterval {
        return intervals.reduce(0) { $0 + $1.duration }
    }
}

struct TrainingInterval: Codable, Identifiable {
    let id = UUID()
    let phase: Phase
    let duration: TimeInterval
    let intensity: Intensity
    
    enum Phase: String, Codable, CaseIterable {
        case warmup = "warmup"
        case work = "work"
        case rest = "rest"
        case cooldown = "cooldown"
    }
    
    enum Intensity: String, Codable, CaseIterable {
        case low = "low"
        case moderate = "moderate"
        case high = "high"
    }
}

struct TrainingSession: Codable, Identifiable {
    let id = UUID()
    let programId: UUID
    let startTime: Date
    let endTime: Date
    let intervals: [SessionInterval]
    
    struct SessionInterval: Codable {
        let intervalId: UUID
        let actualDuration: TimeInterval
        let averageHeartRate: Int?
        let maxHeartRate: Int?
        let distance: Double?
    }
}

enum ProgramType: String, Codable, CaseIterable {
    case walkRun = "walkRun"
    case cycling = "cycling"
    case swimming = "swimming"
    case strength = "strength"
    case custom = "custom"
}
