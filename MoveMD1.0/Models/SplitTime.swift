//
//  SplitTime.swift
//  MoveMD1.0
//
//  Created by Joseph DeWeese on 4/29/25.
//

import SwiftData

@Model
class SplitTime {
    var durationInSeconds: Double
    @Relationship(inverse: \Exercise.splitTimes) var exercise: Exercise?
    @Relationship(inverse: \History.splitTimes) var history: History?
    
    init(durationInSeconds: Double, exercise: Exercise? = nil, history: History? = nil) {
        self.durationInSeconds = durationInSeconds
        self.exercise = exercise
        self.history = history
    }
}
