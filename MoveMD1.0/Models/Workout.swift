//
//  Item.swift
//  MoveMD1.0
//
//  Created by Joseph DeWeese on 4/29/25.
//

import SwiftUI
import SwiftData

@Model
class Workout {
    @Attribute(.unique) var title: String
    var exercises: [Exercise]
    var lastSessionDuration: Double
    var dateCreated: Date
    var dateCompleted: Date?
    var category: Category?
    @Relationship(deleteRule: .cascade) var history: [History]
    var personalBest: Double?
    var aiGeneratedSummary: String?
    @Attribute(.allowsCloudEncryption) var scheduleDate: Date?
    @Attribute(.allowsCloudEncryption) var notificationTime: Date?
    @Attribute(.allowsCloudEncryption) var repeatOption: RepeatOption?
    
    var sortedExercises: [Exercise] {
        exercises.sorted {$0.order < $1.order}
    }
    
    init(
        title: String,
        exercises: [Exercise] = [],
        lastSessionDuration: Double = 0,
        dateCreated: Date = .now,
        dateCompleted: Date? = nil,
        category: Category? = nil,
        history: [History] = [],
        personalBest: Double? = nil,
        aiGeneratedSummary: String? = nil,
        scheduleDate: Date? = nil,
        notificationTime: Date? = nil,
        repeatOption: RepeatOption? = nil
    ) {
        self.title = title
        self.exercises = exercises
        self.lastSessionDuration = lastSessionDuration
        self.dateCreated = dateCreated
        self.dateCompleted = dateCompleted
        self.category = category
        self.history = history
        self.personalBest = personalBest
        self.aiGeneratedSummary = aiGeneratedSummary
        self.scheduleDate = scheduleDate
        self.notificationTime = notificationTime
        self.repeatOption = repeatOption
    }
    
    func updatePersonalBest() {
        print("[Workout.swift] updatePersonalBest called for workout: \(self.title)")
        if history.isEmpty {
            personalBest = nil
            print("[Workout.swift] History is empty, personalBest set to nil.")
        } else {
            let allDurations = history.map { $0.lastSessionDuration }
            print("[Workout.swift] All history durations (minutes): \(allDurations)")
            let validDurations = allDurations.filter { $0 > 0 }
            print("[Workout.swift] Valid ( > 0) history durations (minutes): \(validDurations)")
            
            let newPersonalBest = validDurations.isEmpty ? nil : validDurations.min()
            print("[Workout.swift] Calculated new personalBest (minutes): \(String(describing: newPersonalBest))")
            
            if let currentPB = personalBest {
                print("[Workout.swift] Current personalBest before update (minutes): \(currentPB)")
            } else {
                print("[Workout.swift] Current personalBest before update is nil.")
            }
            
            personalBest = newPersonalBest
            print("[Workout.swift] Final personalBest after update (minutes): \(String(describing: personalBest))")
        }
    }
    
    var fastestDuration: Double {
        history.map { $0.lastSessionDuration }.min() ?? 0.0
    }
    
    func getDefaultDuration() -> Double {
        personalBest ?? fastestDuration
    }
    
    func updateAISummary(context: ModelContext) {
        guard !history.isEmpty else {
            aiGeneratedSummary = nil
            return
        }
        let averageDurationInMinutes = history.map { $0.lastSessionDuration }.reduce(0.0, +) / Double(history.count)
        let averageDurationInSeconds = averageDurationInMinutes * 60
        let exerciseNames = sortedExercises.map { $0.name }.joined(separator: ", ")
        aiGeneratedSummary = "Completed \(history.count) session(s) with an average duration of \(TimeFormatter.formatDuration(averageDurationInSeconds)). Exercises: \(exerciseNames)."
    }
    
    enum RepeatOption: String, CaseIterable, Codable, Identifiable {
        case none = "None"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        var id: String { rawValue }
    }
}
