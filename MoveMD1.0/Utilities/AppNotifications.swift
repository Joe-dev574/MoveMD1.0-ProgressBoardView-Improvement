
// AppNotifications.swift
// This file defines app-wide notification names.

import Foundation

extension Notification.Name {
    /// Notification posted when a workout session has been successfully completed and saved.
    static let workoutDidComplete = Notification.Name("com.movemd.workoutDidComplete")
}
