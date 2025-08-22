
import Foundation

// UnitSystem enum is defined in SettingsView.swift and is accessible globally within the module.
// If it were not, we would need to ensure it's accessible here, possibly by moving its definition
// to a more central location or passing its rawValue/cases as needed.

enum Formatters {
    static func formatTime(minutes: Double) -> String {
        let totalSeconds = Int(minutes * 60)
        let hours = totalSeconds / 3600
        let minutesPart = (totalSeconds % 3600) / 60
        let secondsPart = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutesPart, secondsPart)
        } else if minutesPart > 0 {
            return String(format: "%dm %02ds", minutesPart, secondsPart)
        } else {
            return String(format: "%ds", secondsPart)
        }
    }

    static func formattedWeight(for weightInKg: Double?, in system: UnitSystem, forInput: Bool = false) -> String {
        guard let weightInKg = weightInKg else { return forInput ? "" : "–" }
        if system == .imperial {
            let weightInLbs = weightInKg * 2.20462
            return String(format: "%.1f", weightInLbs) + (forInput ? "" : " lbs")
        } else {
            return String(format: "%.1f", weightInKg) + (forInput ? "" : " kg")
        }
    }

    static func formattedHeight(for heightInMeters: Double?, in system: UnitSystem, forInput: Bool = false) -> String {
        guard let heightInMeters = heightInMeters else { return forInput ? "" : "–" }
        if system == .imperial {
            let totalInches = heightInMeters / 0.0254
            let feet = Int(totalInches / 12)
            let inches = Int(round(totalInches.truncatingRemainder(dividingBy: 12)))
            return forInput ? "\(feet),\(inches)" : "\(feet) ft \(inches) in"
        } else {
            return String(format: "%.2f", heightInMeters) + (forInput ? "" : " m")
        }
    }
}
