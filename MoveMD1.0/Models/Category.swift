//
//  CustomCategory.swift
//  FlowSync
//
//  Created by Joseph DeWeese on 4/26/25.
//

// Category.swift
import SwiftUI
import SwiftData
import HealthKit

enum CategoryColor: String, Codable {
    case CARDIO
    case CROSSTRAIN
    case CYCLING
    case GRAPPLING
    case HIIT
    case PILATES
    case POWER
    case RECOVERY
    case SWIMMING
    case STRENGTH
    case RUN
    case YOGA
    case WALK
    case STRETCH
    case TEST
    
    var color: Color {
        switch self {
        case .CARDIO: return .CARDIO
        case .CROSSTRAIN: return .CROSSTRAIN
        case .CYCLING: return .CYCLING
        case .GRAPPLING: return .GRAPPLING
        case .HIIT: return .HIIT
        case .PILATES: return .PILATES
        case .POWER: return .POWER
        case .RECOVERY: return .RECOVERY
        case .SWIMMING: return .SWIMMING
        case .STRENGTH: return .STRENGTH
        case .RUN: return .RUN
        case .YOGA: return .YOGA
        case .WALK: return .WALK
        case .STRETCH: return .STRETCH
        case .TEST: return .TEST
        }
    }

    var hkActivityType: HKWorkoutActivityType {
        switch self {
        case .CARDIO:
            return .mixedCardio
        case .CROSSTRAIN:
            return .crossTraining
        case .CYCLING:
            return .cycling
        case .GRAPPLING:
            return .martialArts
        case .HIIT:
            return .highIntensityIntervalTraining
        case .PILATES:
            return .pilates
        case .POWER:
            return .traditionalStrengthTraining
        case .RECOVERY:
            return .flexibility
        case .SWIMMING:
            return .swimming
        case .STRENGTH:
            return .traditionalStrengthTraining
        case .RUN:
            return .running
        case .YOGA:
            return .yoga
        case .WALK:
            return .walking
        case .STRETCH:
            return .flexibility
        case .TEST:
            return .other
        }
    }

    var metValue: Double {
        switch self {
        case .CARDIO: return 7.5
        case .CROSSTRAIN: return 8.0
        case .CYCLING: return 7.5
        case .GRAPPLING: return 10.0
        case .HIIT: return 8.0
        case .PILATES: return 3.0
        case .POWER: return 6.0
        case .RECOVERY: return 2.0
        case .SWIMMING: return 7.0
        case .STRENGTH: return 5.0
        case .RUN: return 9.8
        case .YOGA: return 2.5
        case .WALK: return 3.5
        case .STRETCH: return 2.0
        case .TEST: return 5.0
        }
    }
}

@Model
class Category: Identifiable {
    @Attribute(.unique) var categoryName: String
    var symbol: String
    var categoryColor: CategoryColor
    
    init(categoryName: String, symbol: String, categoryColor: CategoryColor = .STRENGTH) {
        self.categoryName = categoryName
        self.symbol = symbol
        self.categoryColor = categoryColor
    }
}
