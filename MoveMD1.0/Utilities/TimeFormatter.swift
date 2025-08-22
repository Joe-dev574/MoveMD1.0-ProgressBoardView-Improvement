import Foundation

/// `TimeFormatter` provides utility functions for formatting time intervals.
struct TimeFormatter {

    /// Formats a duration in seconds into a string representation (e.g., "HH:MM:SS" or "MM:SS").
    ///
    /// - Parameter duration: The duration in seconds.
    /// - Returns: A string representing the formatted duration.
    static func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad

        // Ensure that if hours are zero, they are not displayed unless the duration is very long.
        // For typical workout durations, MM:SS is preferred if hours are 0.
        if duration < 3600 { // Less than 1 hour
            formatter.allowedUnits = [.minute, .second]
        }
        
        return formatter.string(from: duration) ?? "00:00"
    }

    /// Formats a duration in seconds into a concise string, typically for display in lists or summaries.
    /// Example: 30.5s, 1.2m, 1.0h
    /// - Parameter duration: The duration in seconds.
    /// - Returns: A concise string representation of the duration.
    static func formatDurationConcise(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return String(format: "%.1fs", duration)
        } else if duration < 3600 {
            return String(format: "%.1fm", duration / 60)
        } else {
            return String(format: "%.1fh", duration / 3600)
        }
    }
    
    /// Formats a Date into a short time string (e.g., "10:30 AM").
    /// - Parameter date: The date to format.
    /// - Returns: A string representing the short time.
    static func shortTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Formats a Date into a medium date string (e.g., "Sep 12, 2023").
    /// - Parameter date: The date to format.
    /// - Returns: A string representing the medium date.
    static func mediumDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
