//
//  User.swift
//  MoveMD1.0
//
//  Created by Joseph DeWeese on 4/29/25.
//

import SwiftData
import HealthKit // For HKBiologicalSex if we map it, or just for context

/// Represents a single progress selfie taken by the user.
struct ProgressSelfie: Identifiable, Codable, Hashable {
    let id: UUID
    var imageData: Data 
    var dateAdded: Date

    /// Formatted display name for the selfie, e.g., "May '25".
    var displayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yy" 
        return formatter.string(from: dateAdded)
    }

    init(id: UUID = UUID(), imageData: Data, dateAdded: Date = Date()) {
        self.id = id
        self.imageData = imageData
        self.dateAdded = dateAdded
    }
}

/// A SwiftData model representing a user’s onboarding status and health metrics for MoveMD1.0.
/// Stores whether the user has completed onboarding, their Apple ID, and health data from HealthKit.
@Model
final class User {
    // MARK: - Properties
    var appleUserId: String? // Unique identifier from Apple
    var email: String? // Email provided by Apple (can be private relay)
    var isOnboardingComplete: Bool
    
    // Health Metrics
    var weight: Double? // in kilograms
    var height: Double? // in meters
    var age: Int?
    var restingHeartRate: Double? // in beats per minute
    var maxHeartRate: Double? // in beats per minute. Can be user-entered or estimated.
    var biologicalSexString: String? // Storing HKBiologicalSex.description or a custom string
                                    // Options: "Male", "Female", "Other", "Not Set"

    // Profile Details
    var name: String? // Name provided by Apple, or user-set
    var fitnessGoal: String?
    
    @Attribute(.externalStorage) var profileImageData: Data?

    var progressSelfies: [ProgressSelfie] = []

    /// Initializes a User instance.
    init(appleUserId: String? = nil,
         email: String? = nil,
         isOnboardingComplete: Bool = false,
         name: String? = nil,
         fitnessGoal: String? = "General Fitness",
         profileImageData: Data? = nil,
         biologicalSexString: String? = nil,
         progressSelfies: [ProgressSelfie] = []
        ) {
        self.appleUserId = appleUserId
        self.email = email
        self.isOnboardingComplete = isOnboardingComplete
        self.name = name
        self.fitnessGoal = fitnessGoal
        self.profileImageData = profileImageData
        
        // Initialize health metrics
        self.weight = nil
        self.height = nil
        self.age = nil
        self.restingHeartRate = nil
        self.maxHeartRate = nil
        self.biologicalSexString = biologicalSexString
        self.progressSelfies = progressSelfies
    }
}

// Helper to map HKBiologicalSex to a display string, could be part of User or a utility
extension User {
    // Example of how you might want to represent HKBiologicalSex.
    // HealthKitManager would convert HKBiologicalSexObject.biologicalSex to one of these strings.
    enum BiologicalSexDisplay: String, CaseIterable {
        case female = "Female"
        case male = "Male"
        case other = "Other"
        case notSet = "Not Set"

        init(hkBiologicalSex: HKBiologicalSex?) {
            guard let hkSex = hkBiologicalSex else {
                self = .notSet
                return
            }
            switch hkSex {
            case .female: self = .female
            case .male: self = .male
            case .other: self = .other
            case .notSet: self = .notSet
            @unknown default: self = .notSet
            }
        }
        
        var hkValue: HKBiologicalSex {
            switch self {
            case .female: return .female
            case .male: return .male
            case .other: return .other
            case .notSet: return .notSet
            }
        }
    }
    
    // Computed property if you want to work with the enum type easily
    var biologicalSex: BiologicalSexDisplay? {
        get {
            guard let sexString = biologicalSexString else { return nil }
            return BiologicalSexDisplay(rawValue: sexString)
        }
        set {
            biologicalSexString = newValue?.rawValue
        }
    }
}
