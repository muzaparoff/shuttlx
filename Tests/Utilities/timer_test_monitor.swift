#!/usr/bin/env swift

/**
 * Timer Test Monitor
 * 
 * This script monitors simulator logs to detect timer behavior and issues.
 * Run this while testing the timer in the Watch app to see exactly what's happening.
 */

import Foundation

print("🔍 Timer Test Monitor")
print("====================")
print("✅ Both simulators are now running.")
print("")
print("📱 MANUAL TEST INSTRUCTIONS:")
print("1. Open Watch Simulator (should already be showing ShuttlX)")
print("2. Navigate to a training program")
print("3. Press 'Start Workout' button")
print("4. Watch for timer logs below...")
print("")
print("🔍 Expected behavior:")
print("   • Timer should show '05:00' initially")
print("   • Timer should count down every second")
print("   • You should see '⏱️ [TIMER-TICK]' logs every second")
print("")
print("❌ If timer is stuck:")
print("   • No '⏱️ [TIMER-TICK]' logs = Timer not starting")
print("   • '⏱️ [TIMER-TICK]' logs but UI not updating = UI binding issue")
print("")
print("📋 LOG MONITOR:")
print("===============")

// Start log monitoring in background
let task = Process()
task.launchPath = "/usr/bin/xcrun"
task.arguments = ["simctl", "spawn", "8D8AE95A-C200-410A-8C8E-7F52375B0BD8", "log", "stream", "--predicate", "category == 'default' AND subsystem CONTAINS 'com.shuttlx'"]

let pipe = Pipe()
task.standardOutput = pipe
task.standardError = pipe

let fileHandle = pipe.fileHandleForReading

fileHandle.readabilityHandler = { handle in
    let data = handle.availableData
    if let output = String(data: data, encoding: .utf8), !output.isEmpty {
        // Filter for timer-related logs
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("⏱️") || line.contains("TIMER") || line.contains("remainingIntervalTime") || line.contains("START-WORKOUT") {
                print("🔍 \(line)")
            }
        }
    }
}

task.launch()

print("📱 Monitoring watchOS simulator logs...")
print("📱 Perform the timer test now in the Watch Simulator!")
print("")

// Keep the script running
RunLoop.main.run()
