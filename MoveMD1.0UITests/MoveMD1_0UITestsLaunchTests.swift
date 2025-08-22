//
//  MoveMD1_0UITestsLaunchTests.swift
//  MoveMD1.0UITests
//
//  Created by Joseph DeWeese on 4/29/25.
//

import XCTest
import SwiftData

final class MoveMD1_0UITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()
        
        // Pre-populate a workout
        XCTAssertTrue(app.buttons["plus"].waitForExistence(timeout: 5), "Add Workout button not found")
        app.buttons["plus"].tap()
        
        let titleField = app.textFields["workoutTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Title field not found")
        titleField.tap()
        titleField.typeText("Morning Cardio")
        app.buttons["doneButton"].tap()
        
        let categoryButton = app.buttons["categoryButton"]
        XCTAssertTrue(categoryButton.waitForExistence(timeout: 5), "Category button not found")
        categoryButton.tap()
        let hiitButton = app.buttons["category_HIIT"]
        XCTAssertTrue(hiitButton.waitForExistence(timeout: 5), "HIIT category not found")
        hiitButton.tap()
        
        let addExerciseButton = app.buttons["addExerciseButton"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 5), "Add Exercise button not found")
        addExerciseButton.tap()
        let exerciseField = app.textFields["exerciseField"]
        XCTAssertTrue(exerciseField.waitForExistence(timeout: 5), "Exercise field not found")
        exerciseField.tap()
        exerciseField.typeText("Push-ups 10x10")
        app.buttons["doneButton"].tap()
        
        addExerciseButton.tap()
        let secondExerciseField = app.textFields.matching(identifier: "exerciseField").element(boundBy: 1)
        XCTAssertTrue(secondExerciseField.waitForExistence(timeout: 5), "Second exercise field not found")
        secondExerciseField.tap()
        secondExerciseField.typeText("Squats 12x3")
        app.buttons["doneButton"].tap()
        
        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button not found")
        saveButton.tap()
        
        XCTAssertTrue(app.buttons["workoutCard_Morning Cardio"].waitForExistence(timeout: 5), "Workout card not found")
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testAddWorkout() throws {
        XCTAssertTrue(app.buttons["plus"].waitForExistence(timeout: 5))
        app.buttons["plus"].tap()
        
        let titleField = app.textFields["workoutTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Evening Cardio")
        app.buttons["doneButton"].tap()
        
        let categoryButton = app.buttons["categoryButton"]
        XCTAssertTrue(categoryButton.waitForExistence(timeout: 5))
        categoryButton.tap()
        let runButton = app.buttons["category_RUN"]
        XCTAssertTrue(runButton.waitForExistence(timeout: 5))
        runButton.tap()
        
        let addExerciseButton = app.buttons["addExerciseButton"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 5))
        addExerciseButton.tap()
        let exerciseField = app.textFields["exerciseField"]
        XCTAssertTrue(exerciseField.waitForExistence(timeout: 5))
        exerciseField.tap()
        exerciseField.typeText("Jumping Jacks 15x2")
        app.buttons["doneButton"].tap()
        
        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()
        
        XCTAssertTrue(app.buttons["workoutCard_Evening Cardio"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 Exercise"].waitForExistence(timeout: 5))
    }
    
    func testEditWorkout() throws {
        let workoutCard = app.buttons["workoutCard_Morning Cardio"]
        XCTAssertTrue(workoutCard.waitForExistence(timeout: 5))
        workoutCard.tap()
        
        let editButton = app.buttons["editButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()
        
        let titleField = app.textFields["workoutTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.clearText()
        titleField.typeText("Morning Run")
        app.buttons["doneButton"].tap()
        
        let personalBestField = app.textFields["personalBestField"]
        XCTAssertTrue(personalBestField.waitForExistence(timeout: 5))
        personalBestField.tap()
        personalBestField.clearText()
        personalBestField.typeText("45.5")
        app.buttons["doneButton"].tap()
        
        let exerciseField = app.textFields["exerciseField"]
        XCTAssertTrue(exerciseField.waitForExistence(timeout: 5))
        exerciseField.swipeLeft()
        app.buttons["Delete"].tap()
        
        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()
        
        XCTAssertTrue(app.staticTexts["Morning Run"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Personal Record: 00:45:30"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 Exercise"].waitForExistence(timeout: 5))
    }
    
    func testStartWorkoutSession() throws {
        let workoutCard = app.buttons["workoutCard_Morning Cardio"]
        XCTAssertTrue(workoutCard.waitForExistence(timeout: 5))
        workoutCard.tap()
        
        let beginButton = app.buttons["beginWorkoutButton"]
        XCTAssertTrue(beginButton.waitForExistence(timeout: 5))
        beginButton.tap()
        
        let nextButton = app.buttons["nextExerciseButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.tap()
        
        let completeButton = app.buttons["completeWorkoutButton"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()
        
        let detailCard = app.buttons["workoutCard_Morning Cardio"]
        XCTAssertTrue(detailCard.waitForExistence(timeout: 5))
        detailCard.tap()
        XCTAssertTrue(app.staticTexts["History"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[Date().formatted(date: .long, time: .omitted)].waitForExistence(timeout: 5))
    }
    
    func testSettingsView() throws {
        // Navigate to SettingsView
        XCTAssertTrue(app.buttons["gear"].waitForExistence(timeout: 5), "Settings button not found")
        app.buttons["gear"].tap()
        
        // Toggle notifications
        let notificationsToggle = app.switches["notificationsToggle"]
        XCTAssertTrue(notificationsToggle.waitForExistence(timeout: 5), "Notifications toggle not found")
        notificationsToggle.tap()
        
//        // Select theme
//        let themePicker = app.pickers["themePicker"]
//        XCTAssertTrue(themePicker.waitForExistence(timeout: 5), "Theme picker not found")
//        themePicker.selectedT(value: "Dark")
        
        // Dismiss
        let doneButton = app.buttons["doneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5), "Done button not found")
        doneButton.tap()
        
        // Verify back in WorkoutListScreen
        XCTAssertTrue(app.buttons["plus"].waitForExistence(timeout: 5), "WorkoutListScreen not found")
    }
    
    func testProfileView() throws {
        // Navigate to ProfileView
        XCTAssertTrue(app.buttons["person.circle"].waitForExistence(timeout: 5), "Profile button not found")
        app.buttons["person.circle"].tap()
        
        // Update name
        let nameField = app.textFields["nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Name field not found")
        nameField.tap()
        nameField.clearText()
        nameField.typeText("Test User")
        app.buttons["doneButton"].tap()
        
        
        // Save
        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button not found")
        saveButton.tap()
        
        // Verify back in WorkoutListScreen
        XCTAssertTrue(app.buttons["plus"].waitForExistence(timeout: 5), "WorkoutListScreen not found")
    }
    
    func testHistoryView() throws {
        // Open a workout in WorkoutDetailView
        let workoutCard = app.buttons["workoutCard_Morning Cardio"]
        XCTAssertTrue(workoutCard.waitForExistence(timeout: 5), "Morning Cardio workout card not found")
        workoutCard.tap()
        
        // Navigate to HistoryView
        let historyLink = app.cells.containing(.staticText, identifier: Date().formatted(date: .long, time: .omitted)).firstMatch
        XCTAssertTrue(historyLink.waitForExistence(timeout: 5), "History link not found")
        historyLink.tap()
        
        // Verify history details
        XCTAssertTrue(app.staticTexts["historyDuration"].waitForExistence(timeout: 5), "History duration not found")
        XCTAssertTrue(app.staticTexts["historyDate"].waitForExistence(timeout: 5), "History date not found")
    }
    
    func testPurchaseView() throws {
        // Open a workout in WorkoutDetailView
        let workoutCard = app.buttons["workoutCard_Morning Cardio"]
        XCTAssertTrue(workoutCard.waitForExistence(timeout: 5), "Morning Cardio workout card not found")
        workoutCard.tap()

        // Navigate to PurchaseView
        let unlockLink = app.buttons["unlockAISummaryLink"]
        XCTAssertTrue(unlockLink.waitForExistence(timeout: 10), "Unlock link (to PurchaseView) not found") // Increased timeout slightly
        unlockLink.tap()

        // Tap Restore Purchases (avoid actual purchase in tests)
        let restoreButton = app.buttons["restorePurchasesButton"]
        XCTAssertTrue(restoreButton.waitForExistence(timeout: 5), "Restore button not found")
        restoreButton.tap()

        // Verify back in WorkoutDetailView (or wherever restore takes the user - might stay on PurchaseView or dismiss)
        // Depending on the exact behavior after restore (success/failure alert?), this verification might need adjustment.
        // For now, let's assume it stays on or returns to the detail view.
        XCTAssertTrue(app.staticTexts["Morning Cardio"].waitForExistence(timeout: 5), "WorkoutDetailView title not found after attempting restore")
    }
    
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }
}

extension XCUIElement {
    func clearText() {
        guard let stringValue = value as? String else { return }
        tap()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        typeText(deleteString)
    }
}

extension XCUIElementQuery {
    func select(value: String) {
        let pickerWheel = self.pickerWheels.element
        pickerWheel.adjust(toPickerWheelValue: value)
    }
}
