import SwiftUI
import SwiftData
import OSLog
import UserNotifications

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.modelContext) private var modelContext
    // @StateObject private var healthKitManager = HealthKitManager.shared // Using .shared directly
    @State private var showHealthKitPrompt: Bool = false
    @AppStorage("hasPromptedHealthKit") private var hasPromptedHealthKit: Bool = false
    @AppStorage("hasPromptedNotifications") private var hasPromptedNotifications: Bool = false
    @State private var showNotificationPromptAlert: Bool = false // Optional: for guiding to settings if denied
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.movemd.default.subsystem", category: "ContentView")
    
    var body: some View {
        let _ = logger.debug("[ContentView] Body evaluating.")
        buildContent()
            .onAppear {
                logger.debug("[ContentView] Body evaluating.")
                logger.debug("[ContentView] Root content onAppear.")
                if authManager.currentAppleUser == nil {
                    logger.info("[ContentView] Root content onAppear: currentAppleUser is nil.")
                } else {
                    logger.info("[ContentView] Root content onAppear: currentAppleUser exists (Name: \(authManager.currentAppleUser?.appleUserId ?? "N/A"))")
                }
            }
    }
    @ViewBuilder
    private func buildContent() -> some View {
        if authManager.currentAppleUser == nil {
            let _ = logger.debug("[ContentView] CurrentAppleUser is nil. Showing AuthenticationView.")
            AuthenticationView()
        } else {
            if let user = authManager.currentAppleUser {
                if user.isOnboardingComplete {
                    WorkoutListScreen()
                        .onAppear {
                            logger.debug("[ContentView] WorkoutListScreen onAppear.")
                            
                            // --- HealthKit Prompt Logic ---
                            // Check if we haven't prompted before AND HealthKit is not currently authorized (based on non-UI check)
                            if !hasPromptedHealthKit && !HealthKitManager.shared.isAuthorized && user.name != nil {
                                logger.info("[ContentView] Conditions met to show HealthKit prompt (triggering actual permission request).")
                                // Set showHealthKitPrompt to true to show your custom in-app rationale if you have one,
                                // OR directly call requestHealthKitPermissions.
                                // If you have a custom alert that explains *why* you need HealthKit, show that first.
                                // Then, in the "Allow" button of *your* alert, call HealthKitManager.shared.requestHealthKitPermissions.
                                
                                // For now, let's assume your showHealthKitPrompt alert handles this.
                                // The "Allow" button in that alert should now call:
                                // HealthKitManager.shared.requestHealthKitPermissions { success, error in ... }
                                showHealthKitPrompt = true
                            }
                            
                            // --- Notification Permission Logic ---
                            // Check only if we haven't prompted before in this session/install
                            if !hasPromptedNotifications {
                                Task {
                                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                                    logger.info("[ContentView] Notification auth status on WorkoutListScreen appear: \(settings.authorizationStatus.rawValue)")
                                    if settings.authorizationStatus == .notDetermined {
                                        logger.info("[ContentView] Requesting notification permission.")
                                        NotificationManager.shared.requestAuthorization { granted in
                                            DispatchQueue.main.async {
                                                self.hasPromptedNotifications = true // Mark as prompted regardless of grant status
                                                if granted {
                                                    logger.info("[ContentView] Notification permission granted.")
                                                    // Reschedule notifications if needed
                                                    NotificationManager.shared.checkAndRescheduleAllNotifications(modelContext: modelContext)
                                                } else {
                                                    logger.info("[ContentView] Notification permission denied.")
                                                    // Optionally, set a flag to show an alert guiding them to settings
                                                    // self.showNotificationPromptAlert = true
                                                }
                                            }
                                        }
                                    } else {
                                        // Already determined (authorized or denied), just mark as prompted for this logic's purpose
                                        // and ensure notifications are synced with app settings
                                        self.hasPromptedNotifications = true
                                        if settings.authorizationStatus == .authorized {
                                            NotificationManager.shared.checkAndRescheduleAllNotifications(modelContext: modelContext)
                                        }
                                        logger.info("[ContentView] Notification permission already determined. Status: \(settings.authorizationStatus.rawValue)")
                                    }
                                }
                            }
                        }
                        .alert("Enable HealthKit", isPresented: $showHealthKitPrompt) {
                            Button("Allow") {
                                logger.info("[ContentView] HealthKit prompt: 'Allow' tapped. Now requesting actual HK permissions.")
                                HealthKitManager.shared.requestHealthKitPermissions { success, error in
                                    // The isAuthorized property in HealthKitManager will be updated by requestHealthKitPermissions
                                    logger.info("[ContentView] HealthKit permissions request completed. Success: \(success)")
                                    if success {
                                        if authManager.currentAppleUser?.isOnboardingComplete == true {
                                            logger.info("[ContentView] HealthKit authorized and user onboarded, triggering profile data fetch.")
                                            HealthKitManager.shared.fetchAllUserProfileData()
                                        }
                                    } else if let error = error {
                                        logger.error("[ContentView] HealthKit permissions request failed: \(error.localizedDescription)")
                                    }
                                    hasPromptedHealthKit = true
                                }
                            }
                            Button("Not Now", role: .cancel) {
                                logger.info("[ContentView] HealthKit prompt: 'Not Now' tapped.")
                                hasPromptedHealthKit = true
                            }
                        } message: {
                            Text("MoveMD uses HealthKit to save and track your workouts, allowing you to see your fitness data in the Health app.")
                        }
                    // Optional: Alert if notification permission was denied and you want to guide user
                    // .alert("Enable Notifications", isPresented: $showNotificationPromptAlert) {
                    //     Button("Open Settings") { /* Code to open app settings */ }
                    //     Button("Not Now", role: .cancel) {}
                    // } message: {
                    //     Text("To receive workout reminders, please enable notifications in the Settings app.")
                    // }
                } else {
                    let _ = logger.debug("[ContentView] User onboarding NOT complete. Showing OnboardingFlowView.")
                    OnboardingFlowView(user: user)
                }
            } else {
                let _ = logger.error("[ContentView] Fallback: CurrentAppleUser was non-nil then became nil before onboarding check. Showing AuthenticationView.")
                AuthenticationView()
            }
        }
    }
    
    
#if DEBUG
    struct ContentView_Previews: PreviewProvider {
        @MainActor static var previews: some View {
            let authManager_loggedIn_onboarded = AuthenticationManager()
            let user_onboarded = User(appleUserId: "onboarded_user")
            user_onboarded.isOnboardingComplete = true
            authManager_loggedIn_onboarded.currentAppleUser = user_onboarded
            
            let authManager_loggedIn_not_onboarded = AuthenticationManager()
            let user_not_onboarded = User(appleUserId: "not_onboarded_user")
            user_not_onboarded.isOnboardingComplete = false
            authManager_loggedIn_not_onboarded.currentAppleUser = user_not_onboarded
            
            let authManager_loggedOut = AuthenticationManager()
            
            
            let container = PersistenceController.previewContainer
            
            return Group {
                ContentView()
                    .environmentObject(authManager_loggedIn_onboarded)
                    .modelContainer(container)
                    .previewDisplayName("Logged In, Unlocked, Onboarded")
                
                ContentView()
                    .environmentObject(authManager_loggedIn_not_onboarded)
                    .modelContainer(container)
                    .previewDisplayName("Logged In, Unlocked, Not Onboarded")
                
                ContentView()
                    .environmentObject(authManager_loggedIn_onboarded)
                    .modelContainer(container)
                    .previewDisplayName("Logged In, Locked")
                
                ContentView()
                    .environmentObject(authManager_loggedOut)
                    .modelContainer(container)
                    .previewDisplayName("Logged Out")
            }
        }
    }
    
#endif
}
