//
//  UtilitiesTest.swift
//  MoveMD1.0Tests
//
//  Created by Joseph DeWeese on 5/1/25.
//

import XCTest
@testable import MoveMD1_0
import SwiftData

class UtilitiesTests: XCTestCase {
    func testFormatTime() {
        XCTAssertEqual(formatTime(minutes: 90.75), "01:30:45")
        XCTAssertEqual(formatTime(minutes: 0.0), "00:00:00")
        XCTAssertEqual(formatTime(minutes: nil), "N/A")
       
    }
    @MainActor func testWorkoutSavePerformance() {
        let container = try! ModelContainer(for: Workout.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let workout = Workout(title: "Test", exercises: (0..<20).map { Exercise(name: "Exercise \($0)") }, durationInMinutes: 60.0)
        measure {
            context.insert(workout)
            try! context.save()
        }
    }
    
}
