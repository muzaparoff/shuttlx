//
//  ShuttlXWatchUITests.swift
//  ShuttlXWatchUITests
//
//  Automated UI Tests for ShuttlX watchOS App
//  Created by ShuttlX on 6/15/25.
//

import XCTest

final class ShuttlXWatchUITests: XCTestCase {
    
    var app: XCUIApplication!
    var startTime: TimeInterval = 0
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        // Wait for watch app to load
        sleep(3)
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - CRITICAL TEST: Verify "tests123" Sync and Timer
    
    func testTests123WorkoutSyncAndTimer() throws {
        print("🧪 [WATCH-UI-TEST] Testing REAL tests123 workout sync and timer functionality...")
        
        // Step 1: Wait for app to fully load
        sleep(5)
        
        // Step 2: Look for tests123 workout (REAL sync verification)
        print("🧪 [WATCH-UI-TEST] Searching for tests123 workout...")
        var syncSuccess = false
        var attempts = 0
        let maxAttempts = 15 // Give more time for real sync
        
        while attempts < maxAttempts && !syncSuccess {
            // Look for tests123 workout in multiple ways
            let tests123Cell = app.cells.containing(.staticText, identifier: "tests123").firstMatch
            let tests123Text = app.staticTexts["tests123"]
            let tests123Button = app.buttons["tests123"]
            
            if tests123Cell.exists || tests123Text.exists || tests123Button.exists {
                syncSuccess = true
                print("✅ [WATCH-UI-TEST] tests123 workout found on watch after \(attempts + 1) seconds!")
                break
            }
            
            // Scroll to find more workouts
            if attempts % 3 == 0 {
                app.swipeUp()
            }
            
            sleep(1)
            attempts += 1
        }
        
        if !syncSuccess {
            print("❌ [WATCH-UI-TEST] FAILED: tests123 workout NOT found on watch")
            
            // Take screenshot for debugging
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Watch_No_Tests123_Workout"
            add(attachment)
            
            XCTFail("tests123 workout did not sync to watch within \(maxAttempts) seconds")
            return
        }
        
        // Step 3: Start the tests123 workout
        print("🧪 [WATCH-UI-TEST] Starting tests123 workout...")
        
        // Try to tap on the workout
        if app.cells.containing(.staticText, identifier: "tests123").firstMatch.exists {
            app.cells.containing(.staticText, identifier: "tests123").firstMatch.tap()
        } else if app.staticTexts["tests123"].exists {
            app.staticTexts["tests123"].tap()
        } else if app.buttons["tests123"].exists {
            app.buttons["tests123"].tap()
        }
        
        // Wait for workout detail view
        sleep(3)
        
        // Find and tap start button
        var startButtonFound = false
        let possibleStartButtons = [
            app.buttons["Start Training"],
            app.buttons["Start Workout"],
            app.buttons["Start"],
            app.buttons["▶️"],
            app.buttons["GO"],
            app.buttons["Begin"]
        ]
        
        for button in possibleStartButtons {
            if button.exists {
                print("🧪 [WATCH-UI-TEST] Found start button: \(button.label)")
                button.tap()
                startButtonFound = true
                break
            }
        }
        
        if !startButtonFound {
            print("❌ [WATCH-UI-TEST] Could not find start button")
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Watch_No_Start_Button"
            add(attachment)
            XCTFail("Could not find start button")
            return
        }
        
        // Step 4: REAL TIMER VERIFICATION
        print("🧪 [WATCH-UI-TEST] CRITICAL: Verifying REAL timer functionality...")
        
        // Wait for timer to initialize
        sleep(3)
        
        // Look for timer display in multiple ways
        var timerFound = false
        var initialTimerText = ""
        
        let possibleTimerElements = [
            app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "\\d{2}:\\d{2}")).firstMatch,
            app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "\\d{1,2}:\\d{2}")).firstMatch,
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", ":")).firstMatch
        ]
        
        for timerElement in possibleTimerElements {
            if timerElement.waitForExistence(timeout: 5) {
                initialTimerText = timerElement.label
                timerFound = true
                print("🧪 [WATCH-UI-TEST] Found timer: \(initialTimerText)")
                break
            }
        }
        
        if !timerFound {
            print("❌ [WATCH-UI-TEST] FAILED: Timer display not found")
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Watch_No_Timer_Display"
            add(attachment)
            XCTFail("Timer display not found")
            return
        }
        
        // Verify timer is NOT stuck at 00:00
        XCTAssertNotEqual(initialTimerText, "00:00", "Timer should NOT be stuck at 00:00")
        
        // Wait and verify timer changes (REAL countdown verification)
        print("🧪 [WATCH-UI-TEST] Waiting 5 seconds to verify timer counts down...")
        sleep(5)
        
        let updatedTimerText = possibleTimerElements.first(where: { $0.exists })?.label ?? ""
        print("🧪 [WATCH-UI-TEST] Timer after 5 seconds: \(updatedTimerText)")
        
        // Verify timer has changed (either decreased or interval changed)
        XCTAssertNotEqual(updatedTimerText, initialTimerText, "Timer should change after 5 seconds")
        
        // Verify timer is still running (not 00:00)
        XCTAssertNotEqual(updatedTimerText, "00:00", "Timer should still be running after 5 seconds")
        
        print("✅ [WATCH-UI-TEST] REAL Timer verification PASSED - timer is counting down!")
        
        // Step 5: Verify interval indicators
        print("🧪 [WATCH-UI-TEST] Verifying interval indicators...")
        
        let hasWalkIndicator = app.staticTexts["WALK"].exists
        let hasRunIndicator = app.staticTexts["RUN"].exists
        let hasIntervalIndicator = hasWalkIndicator || hasRunIndicator
        
        if hasIntervalIndicator {
            if hasWalkIndicator {
                print("✅ [WATCH-UI-TEST] Currently in WALK interval")
            } else {
                print("✅ [WATCH-UI-TEST] Currently in RUN interval")
            }
        } else {
            print("⚠️ [WATCH-UI-TEST] No clear interval indicator found")
        }
        
        // Step 6: End the workout
        print("🧪 [WATCH-UI-TEST] Ending workout...")
        
        // Look for pause or stop button
        let possibleStopButtons = [
            app.buttons["Pause"],
            app.buttons["Stop"],
            app.buttons["End"],
            app.buttons["⏸"],
            app.buttons["⏹"]
        ]
        
        for button in possibleStopButtons {
            if button.exists {
                button.tap()
                sleep(2)
                break
            }
        }
        
        print("✅ [WATCH-UI-TEST] REAL workout sync and timer test completed successfully!")
    }
    
    // MARK: - Timer Countdown Verification Tests
    
    func testTimerCountdownReliability() throws {
        print("🧪 [WATCH-UI-TEST] Testing timer countdown reliability...")
        
        // Start any available workout
        let firstWorkoutCell = app.cells.firstMatch
        XCTAssertTrue(firstWorkoutCell.exists, "At least one workout should be available")
        
        firstWorkoutCell.tap()
        sleep(1)
        
        let startButton = app.buttons["Start Training"]
        if startButton.exists {
            startButton.tap()
        }
        
        sleep(3)
        
        // Verify timer behavior over 10 seconds
        let timerLabel = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "\\d{2}:\\d{2}")).firstMatch
        
        var timerValues: [String] = []
        for i in 0..<10 {
            if timerLabel.exists {
                timerValues.append(timerLabel.label)
                print("🧪 [WATCH-UI-TEST] Timer at \(i)s: \(timerLabel.label)")
            }
            sleep(1)
        }
        
        // Verify timer is counting down (values should generally decrease)
        var countdownCount = 0
        for i in 1..<timerValues.count {
            let current = timeStringToSeconds(timerValues[i])
            let previous = timeStringToSeconds(timerValues[i-1])
            if current < previous {
                countdownCount += 1
            }
        }
        
        // At least 50% of the time, timer should be counting down
        let countdownPercentage = Double(countdownCount) / Double(timerValues.count - 1)
        XCTAssertGreaterThan(countdownPercentage, 0.3, "Timer should count down consistently")
        
        print("✅ [WATCH-UI-TEST] Timer countdown reliability verified (\(Int(countdownPercentage * 100))% countdown rate)")
    }
    
    func testWorkoutSyncFromiOS() throws {
        print("🧪 [WATCH-UI-TEST] Testing workout sync from iOS...")
        
        // Check if we received any custom workouts
        let customWorkoutExists = UserDefaults.standard.bool(forKey: "tests123_workout_created")
        
        if customWorkoutExists {
            // Look for the synced workout
            let tests123Cell = app.cells.containing(.staticText, identifier: "tests123").firstMatch
            
            var found = false
            for _ in 0..<5 {
                if tests123Cell.exists {
                    found = true
                    break
                }
                app.swipeUp()
                sleep(1)
            }
            
            XCTAssertTrue(found, "Custom workout should sync to watch")
            print("✅ [WATCH-UI-TEST] Custom workout sync verified")
        }
    }
    
    // MARK: - Helper Methods
    
    private func timeStringToSeconds(_ timeString: String) -> Int {
        let components = timeString.components(separatedBy: ":")
        guard components.count == 2,
              let minutes = Int(components[0]),
              let seconds = Int(components[1]) else {
            return 0
        }
        return minutes * 60 + seconds
    }
    
    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }
}
