//
//  WatchTimerUITests.swift
//  ShuttlXWatchTests
//
//  UI Tests for watchOS timer countdown functionality
//  Created on June 14, 2025
//

import XCTest

class WatchTimerUITests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    func testTimerCountdownInUI() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Look for any training program
        let trainingProgram = app.buttons.matching(identifier: "training_program").firstMatch
        
        if trainingProgram.waitForExistence(timeout: 5.0) {
            trainingProgram.tap()
            
            // Look for start workout button
            let startButton = app.buttons["Start Training"]
            if startButton.waitForExistence(timeout: 3.0) {
                startButton.tap()
                
                // Look for timer display
                let timerDisplay = app.staticTexts.matching(NSPredicate(format: "label CONTAINS ':'")).firstMatch
                
                if timerDisplay.waitForExistence(timeout: 5.0) {
                    let initialTime = timerDisplay.label
                    print("Initial timer: \(initialTime)")
                    
                    // Wait 3 seconds and check if timer changed
                    sleep(3)
                    
                    let updatedTime = timerDisplay.label
                    print("Updated timer: \(updatedTime)")
                    
                    // The timer should have changed
                    XCTAssertNotEqual(initialTime, updatedTime, "Timer should count down and change")
                    
                    // Stop the workout if possible
                    if app.buttons["Stop"].exists {
                        app.buttons["Stop"].tap()
                    }
                } else {
                    XCTFail("Timer display not found")
                }
            } else {
                XCTFail("Start Training button not found")
            }
        } else {
            XCTFail("No training program found")
        }
    }
}
