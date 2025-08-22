//
//  History.swift
//  MoveMD1.0
//
//  Created by Joseph DeWeese on 4/29/25.
//

// History.swift
import SwiftUI
import SwiftData

@Model
class History {
    var id: UUID
    var date: Date
    var notes: String?
    var exercisesCompleted: [Exercise]
    @Relationship(deleteRule: .cascade, inverse: \SplitTime.exercise) var splitTimes: [SplitTime]
    var lastSessionDuration: Double
    @Relationship(inverse: \Workout.history) var workout: Workout?
    var intensityScore: Double? // Premium: Heart rate-based intensity
    var progressPulseScore: Double? // Premium: Improvement, frequency, intensity
    var dominantZone: Int? // Premium: Dominant heart rate zone (1–5)

    init(
        id: UUID = UUID(),
        date: Date = .now,
        notes: String? = nil,
        exercisesCompleted: [Exercise] = [],
        splitTimes: [SplitTime] = [],
        lastSessionDuration: Double = 0.0,
        intensityScore: Double? = nil,
        progressPulseScore: Double? = nil,
        dominantZone: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.notes = notes
        self.exercisesCompleted = exercisesCompleted
        self.splitTimes = splitTimes
        self.lastSessionDuration = lastSessionDuration
        self.intensityScore = intensityScore
        self.progressPulseScore = progressPulseScore
        self.dominantZone = dominantZone
    }
}
