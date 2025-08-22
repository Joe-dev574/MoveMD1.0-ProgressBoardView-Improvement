//
//  AddWorkoutUITest.swift
//  MoveMD1.0UITests
//
//  Created by Joseph DeWeese on 5/1/25.
//

import XCTest

class AddWorkoutUITests: XCTestCase {
    func testAddWorkout() {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to AddWorkoutView (adjust based on your app's navigation)
        app.buttons["Add Workout"].tap()
        
        // Enter title
        let titleField = app.textFields["Name of Workout..."]
        titleField.tap()
        titleField.typeText("Morning Cardio")
        
        // Select category
        app.buttons["Select Category"].tap()
        app.buttons["HIIT"].tap()
        
        // Add exercise
        app.buttons["Add Exercise"].tap()
        let exerciseField = app.textFields["Exercise (e.g., Push-ups 10x10)"]
        exerciseField.tap()
        exerciseField.typeText("Push-ups 10x10")
        app.buttons["Done"].tap()
        
        // Set duration
        let slider = app.sliders.element
        slider.adjust(toNormalizedSliderPosition: 0.5) // ~60 minutes
        
        // Save
        app.buttons["Save"].tap()
        
        // Verify workout in WorkoutCard (adjust based on UI)
        XCTAssertTrue(app.staticTexts["Morning Cardio"].exists)
    }
}
