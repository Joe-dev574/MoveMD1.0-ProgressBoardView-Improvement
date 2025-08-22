//
//  SettingsView.swift
//  MoveMD1.0
//
//  Created by Joseph DeWeese on 4/29/25.
//
// SettingsView.swift
import SwiftUI
import SwiftData
import StoreKit

enum UnitSystem: String, CaseIterable, Identifiable {
    case metric = "Metric (kg, m)"
    case imperial = "Imperial (lbs, ft)"

    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .metric:
            return "Metric (kg, m)"
        case .imperial:
            return "Imperial (lbs, ft)"
        }
    }
}

enum AppearanceSetting: String, CaseIterable, Identifiable {
    case system = "System Default"
    case light = "Light Mode"
    case dark = "Dark Mode"

    var id: String { self.rawValue }
    
    var displayName: String {
        return self.rawValue
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var errorManager: ErrorManager

    @Query private var categories: [Category]

    @AppStorage("isHealthKitSyncEnabled") private var isHealthKitSyncEnabled: Bool = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true {
        didSet {
            Task { @MainActor in 
                if notificationsEnabled {
                    NotificationManager.shared.checkAndRescheduleAllNotifications(modelContext: modelContext)
                } else {
                    NotificationManager.shared.cancelAllNotifications()
                }
            }
        }
    }
    @AppStorage("defaultCategoryID") private var defaultCategoryID: String?
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .metric
    @AppStorage("appearanceSetting") private var appearanceSetting: AppearanceSetting = .system
    
    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var showAuthorizationError: Bool = false
    @State private var showSignOutConfirmation = false
    @State private var showNotificationPermissionAlert = false
    @State private var notificationAlertMessage = ""

    private var currentColorForPicker: Binding<Color> {
        Binding(
            get: { Color(hex: selectedThemeColorData) ?? .blue },
            set: { newValue in
                selectedThemeColorData = newValue.hex
            }
        )
    }
    
    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.gray.opacity(0.02), .gray.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            NavigationStack {
                Form {
                    generalSection
                    notificationsSection
                    healthKitSyncSection
                    accountSection
                    aboutSection
                    supportSection
                    rateAppSection
                }
                .scrollContentBackground(.hidden)
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .tint(themeColor)
            }
            .alert("Notification Permission", isPresented: $showNotificationPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(notificationAlertMessage)
            }
        }
    }
    
    private var generalSection: some View {
        Section {
            HStack {
                Image(systemName: "paintpalette")
                    .foregroundStyle(themeColor)
                ColorPicker("Theme Color", selection: currentColorForPicker)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("themeColorPicker")
                    .accessibilityLabel("Theme color")
                    .accessibilityHint("Select a color to customize the app's appearance")
            }
            
            Picker("Appearance", selection: $appearanceSetting) {
                ForEach(AppearanceSetting.allCases) { setting in
                    Text(setting.displayName).tag(setting)
                }
            }
            .foregroundStyle(.primary)
            .accessibilityIdentifier("appearancePicker")
            .accessibilityLabel("Appearance mode")
            .accessibilityHint("Select the app's appearance: light, dark, or system default.")

            Picker("Units of Measure", selection: $unitSystem) {
                ForEach(UnitSystem.allCases) { system in
                    Text(system.displayName).tag(system)
                }
            }
            .foregroundStyle(.primary)
            .accessibilityIdentifier("unitSystemPicker")
            .accessibilityLabel("Units of measure")
            .accessibilityHint("Select your preferred units for weight and height.")

        } header: {
            Text("General")
                .font(.system(size: 18, design: .serif))
                .fontWeight(.semibold)
                .foregroundStyle(themeColor)
        }
    }
    
    private var notificationsSection: some View {
        Section {
            Toggle(isOn: $notificationsEnabled) {
                HStack {
                    Image(systemName: "bell")
                        .foregroundStyle(themeColor)
                        .font(.system(size: 16))
                    Text("Workout Reminders")
                        .foregroundStyle(.primary)
                        .font(.system(size: 16))
                }
            }
            .accessibilityIdentifier("notificationsToggle")
            .accessibilityLabel("Workout reminders")
            .accessibilityHint(notificationsEnabled ? "Disable workout reminder notifications" : "Enable workout reminder notifications")
            .accessibilityValue(notificationsEnabled ? "On" : "Off")
        } header: {
            Text("Notifications")
                .font(.system(size: 18, design: .serif))
                .fontWeight(.semibold)
                .foregroundStyle(themeColor)
        }
    }
    
    private var healthKitSyncSection: some View {
        Section(content: {
            Toggle("Enable HealthKit Sync", isOn: $isHealthKitSyncEnabled)
                .foregroundStyle(.primary)
            
            if isHealthKitSyncEnabled && !healthKitManager.isAuthorized {
                Button("Grant HealthKit Permission") {
                    healthKitManager.requestHealthKitPermissions { granted, error in
                        if let error = error {
                            print("Error requesting HealthKit permissions from Settings: \(error.localizedDescription)")
                            errorManager.presentAlert(title: "HealthKit Error", message: "Could not process HealthKit permissions: \(error.localizedDescription)")
                        }
                        if granted {
                            print("HealthKit permission granted from Settings.")
                        } else {
                            print("HealthKit permission denied or not fully granted from Settings.")
                        }
                    }
                }
                .foregroundStyle(.primary)
                Text("HealthKit permission is required to enable syncing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if isHealthKitSyncEnabled && healthKitManager.isAuthorized {
                Text("HealthKit sync is enabled.")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else if !isHealthKitSyncEnabled {
                Text("HealthKit sync is disabled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }, header: {
            Text("HealthKit Sync")
                .font(.system(size: 18, design: .serif))
                .fontWeight(.semibold)
                .foregroundStyle(themeColor)
        })
        .alert("Authorization Required", isPresented: $showAuthorizationError) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel") { showAuthorizationError = false }
        } message: {
            Text("Please grant HealthKit permission in Settings to enable syncing.")
        }
    }

    private var accountSection: some View {
        Section {
            Button("Sign Out", role: .destructive) {
                showSignOutConfirmation = true
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .font(.system(size: 15, weight: .semibold))
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        } header: {
            Text("Account")
                .font(.system(size: 18, design: .serif))
                .fontWeight(.semibold)
                .foregroundStyle(themeColor)
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(themeColor)
                    .font(.system(size: 16))
                Text("Version")
                    .foregroundStyle(.primary)
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("versionInfo")
            .accessibilityLabel("App version")
            .accessibilityValue("1.0.0")
            
            Link("Privacy Policy", destination: URL(string: "https://movemd.app/privacy")!)
                .foregroundStyle(.primary)
                .accessibilityIdentifier("privacyPolicyLink")
                .accessibilityLabel("Privacy policy")
                .accessibilityHint("Open the app's privacy policy")
            
            Link("Terms of Use", destination: URL(string: "https://movemd.app/terms")!)
                .foregroundStyle(.primary)
                .accessibilityIdentifier("termsLink")
                .accessibilityLabel("Terms of use")
                .accessibilityHint("Open the app's terms of use")
        } header: {
            Text("About")
                .font(.system(size: 18, design: .serif))
                .fontWeight(.semibold)
                .foregroundStyle(themeColor)
        }
    }
    
    private var supportSection: some View {
        Section {
            Link("Contact Support", destination: URL(string: "mailto:support@movemd.app")!)
                .foregroundStyle(.primary)
                .accessibilityIdentifier("contactSupportLink")
                .accessibilityLabel("Contact support")
                .accessibilityHint("Send an email to the support team")
            
            Link("Report a Bug", destination: URL(string: "https://movemd.app/bug-report")!)
                .foregroundStyle(.primary)
                .accessibilityIdentifier("reportBugLink")
                .accessibilityLabel("Report a bug")
                .accessibilityHint("Open a form to report a bug")
        } header: {
            Text("Support")
                .font(.system(size: 18, design: .serif))
                .fontWeight(.semibold)
                .foregroundStyle(themeColor)
        }
    }
    
    private var rateAppSection: some View {
        Section {
            Button(action: requestAppReview) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 16))
                    Text("Rate MoveMD")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(themeColor)
                }
            }
            .accessibilityIdentifier("rateAppButton")
            .accessibilityLabel("Rate MoveMD")
            .accessibilityHint("Request to rate the app in the App Store")
        } header: {
            Text("Rate the App")
                .font(.system(size: 18, design: .serif))
                .fontWeight(.semibold)
                .foregroundStyle(themeColor)
        }
    }
    
    private func requestAppReview() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
}

extension Color {
    init?(hex: String) {
        let r, g, b: Double
        let hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        
        guard hexString.count == 6, let hexNumber = UInt64(hexString, radix: 16) else { return nil }
        
        r = Double((hexNumber >> 16) & 0xFF) / 255.0
        g = Double((hexNumber >> 8) & 0xFF) / 255.0
        b = Double(hexNumber & 0xFF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    var hex: String {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else { return "#000000" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        return NavigationStack {
            SettingsView()
                .environmentObject(authManager)
        }
    }
}
#endif
