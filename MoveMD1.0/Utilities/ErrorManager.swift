//
//  ErrorManager.swift
//  MoveMD1.0
//
//  Created by Alex (AI Assistant) on 5/13/25.
//

import SwiftUI

// Struct to define the properties of an alert to be displayed
struct AppAlert: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var primaryButton: Alert.Button = .default(Text("OK"))
    var secondaryButton: Alert.Button? = nil // Optional secondary button
    // You could add more properties like specific actions for buttons if needed
}

@MainActor // Ensure all operations on this class happen on the main actor
class ErrorManager: ObservableObject {
    static let shared = ErrorManager()

    @Published var currentAlert: AppAlert?

    // Ensure init is private if you only want it used via .shared
    // For now, let's leave it internal/public to not break @StateObject in MoveMD1_0App,
    // but ideally, if it's a true singleton, init would be private.
    // We can refine this once all managers are updated.
    // private init() {} // Example if making it a strict singleton

    // Presents an error with a custom title and message
    func presentAlert(title: String, message: String, primaryButton: Alert.Button = .default(Text("OK")), secondaryButton: Alert.Button? = nil) {
        // Basic logging for now, can be expanded
        print("Presenting Alert: \(title) - \(message)")
        self.currentAlert = AppAlert(title: title, message: message, primaryButton: primaryButton, secondaryButton: secondaryButton)
    }

    // Presents an error conforming to LocalizedError
    func presentError(_ error: LocalizedError, primaryButton: Alert.Button = .default(Text("OK")), secondaryButton: Alert.Button? = nil) {
        let title = error.errorDescription ?? "Error"
        // Combine failureReason and recoverySuggestion into the message if they exist
        var detailedMessage = error.failureReason ?? error.localizedDescription
        if let recovery = error.recoverySuggestion, !recovery.isEmpty {
            detailedMessage += "\n\n\(recovery)"
        }
        
        print("Presenting LocalizedError: \(title) - \(detailedMessage)")
        self.currentAlert = AppAlert(title: title, message: detailedMessage, primaryButton: primaryButton, secondaryButton: secondaryButton)
    }

    // Convenience for common unknown errors
    func presentUnknownError(_ underlyingError: Error? = nil) {
        var message = "An unexpected error occurred. Please try again."
        if let underlyingError = underlyingError {
            message += "\n\nDetails: \(underlyingError.localizedDescription)"
        }
        presentAlert(title: "Error", message: message)
    }
    
    // Call this to dismiss the current alert (by setting currentAlert to nil)
    func dismissAlert() {
        self.currentAlert = nil
    }
}
