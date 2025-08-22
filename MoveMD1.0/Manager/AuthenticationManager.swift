//
//  AuthenticationManager.swift
//  MoveMD1.0
//
//  Created by Joseph DeWeese on 5/12/25.
//

// AuthenticationManager.swift
import SwiftUI
import AuthenticationServices
import SwiftData
import OSLog
import Security

@MainActor
final class AuthenticationManager: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    @Published var currentAppleUser: User? {
        didSet {
            HealthKitManager.shared.setCurrentAppleUserId(currentAppleUser?.appleUserId)
            if let user = currentAppleUser, oldValue == nil { // User just logged in
                Task { // Use a Task for async operations
                    await self.fetchHealthDataForCurrentUserIfNeeded(user: user)
                }
            } else if let user = currentAppleUser, oldValue != nil && user.appleUserId != oldValue?.appleUserId { // User changed (should not happen with Apple Sign In usually, but good practice)
                 Task {
                    await self.fetchHealthDataForCurrentUserIfNeeded(user: user)
                }
            }
        }
    }
    private var modelContext: ModelContext?
    private let keychainService: String
    private let appleUserIdKeychainAccount = "appleUserId"

    private let logger: Logger

    override init() {
        let bundleId = Bundle.main.bundleIdentifier
        self.keychainService = bundleId ?? "com.movemd.default.service"
        self.logger = Logger(subsystem: bundleId ?? "com.movemd.default.subsystem", category: "AuthenticationManager")
        super.init()
        
        logger.debug("[Init] AuthenticationManager initialized.")
        
        if bundleId == nil {
            logger.warning("[Init] Bundle identifier is nil. Using fallback for keychain service and logger subsystem.")
        }
    }

    func configureWithModelContext(_ modelContext: ModelContext) {
        logger.debug("[Configure] Starting configureWithModelContext.")
        self.modelContext = modelContext
        logger.info("[Configure] ModelContext configured.")
        attemptToLoadUserFromStorage()
        logger.debug("[Configure] Finished configureWithModelContext.")
    }
    //MARK:  APPLE SIGN IN
    func handleSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        logger.info("Handling Sign In With Apple request, scopes: fullName, email.")
    }

    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>, window: UIWindow?) {
        logger.info("Handling Sign In With Apple completion.")
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                let errorMsg = "Failed to get Apple ID Credential."
                logger.error("\(errorMsg)")
                ErrorManager.shared.presentAlert(title: "Authentication Error", message: errorMsg)
                return
            }
            
            let userId = appleIDCredential.user
            let email = appleIDCredential.email
            let fullName = appleIDCredential.fullName
            
            logger.debug("""
                [AuthCompletion] Apple ID Credential Details:
                User ID: \(userId.prefix(8))...
                Email: \(email ?? "Not provided")
                Full Name Given: \(fullName?.givenName ?? "Not provided")
                Full Name Family: \(fullName?.familyName ?? "Not provided")
                Full Name Formatted: \(fullName != nil ? PersonNameComponentsFormatter().string(from: fullName!) : "Not provided")
                """)
            
            logger.info("Sign In With Apple success for userId: \(userId.prefix(8))...")

            if saveUserIdToKeychain(userId) {
                logger.info("Apple User ID (prefix: \(userId.prefix(8))...) stored in Keychain.")
            } else {
                let errorMsg = "Could not securely store your user ID. Please try signing in again."
                logger.error("Failed to store Apple User ID \(userId.prefix(8))... in Keychain. \(errorMsg)")
                ErrorManager.shared.presentAlert(title: "Authentication Error", message: errorMsg)
                return
            }
            fetchOrCreateUser(userId: userId, email: email, fullName: fullName)

        case .failure(let error):
            if let asError = error as? ASAuthorizationError {
                var specificErrorMessage = "An unknown Sign In With Apple error occurred."
                logger.error("Sign In With Apple ASAuthorizationError Code: \(asError.code.rawValue) - \(asError.localizedDescription)")
                switch asError.code {
                case .canceled:
                    specificErrorMessage = "Sign in with Apple was canceled by the user."
                    logger.info("\(specificErrorMessage)")
                    return // Exit early if user cancelled
                case .failed:
                    specificErrorMessage = "Sign in with Apple failed. Please try again."
                case .invalidResponse:
                    specificErrorMessage = "Sign in with Apple received an invalid response. Please try again."
                case .notHandled:
                    specificErrorMessage = "Sign in with Apple was not handled. Please try again."
                case .unknown:
                    specificErrorMessage = "An unknown Sign In With Apple error occurred. Please try again."
                case .notInteractive:
                    specificErrorMessage = "Sign in with Apple was not interactive. Please ensure the app is in the foreground."
                case .credentialImport:
                    specificErrorMessage = "Sign in with Apple encountered an issue importing credentials."
                case .matchedExcludedCredential:
                    specificErrorMessage = "Sign in with Apple matched a credential that has been excluded."
                case .credentialExport:
                    specificErrorMessage = "Sign in with Apple encountered an issue exporting credentials."
                @unknown default:
                    logger.error("An unexpected ASAuthorizationError.Code (\(asError.code.rawValue)) occurred during Sign in with Apple.")
                    specificErrorMessage = "An unexpected error occurred during Sign in with Apple."
                }
                ErrorManager.shared.presentAlert(title: "Sign-In Failed", message: specificErrorMessage)
            } else {
                logger.error("Sign In With Apple failed with a non-ASAuthorizationError: \(error.localizedDescription)")
                ErrorManager.shared.presentAlert(title: "Sign-In Error", message: "An unexpected error occurred during sign in: \(error.localizedDescription)")
            }
        }
    }

    private func fetchOrCreateUser(userId: String, email: String?, fullName: PersonNameComponents?) {
        logger.debug("[UserStore] Starting fetchOrCreateUser for userId (prefix: \(userId.prefix(8))...). Email provided: \(email != nil), FullName provided: \(fullName != nil).")
        guard let modelContext = modelContext else {
            let errorMsg = "ModelContext not available in fetchOrCreateUser."
            logger.critical("\(errorMsg)")
            ErrorManager.shared.presentAlert(title: "Account Setup Error", message: "A problem occurred setting up your account. Please try again.")
            return
        }
        
        let providedNameString = fullName != nil ? PersonNameComponentsFormatter().string(from: fullName!) : "nil"
        logger.info("[UserStore] fetchOrCreateUser called with: UserID: \(userId.prefix(8)), Email: \(email ?? "nil"), FullName: \(providedNameString)")

        let fetchDescriptor = FetchDescriptor<User>(predicate: #Predicate { $0.appleUserId == userId })

        do {
            logger.debug("[UserStore] Attempting to fetch user from SwiftData.")
            var userToSet: User?

            if let existingUser = try modelContext.fetch(fetchDescriptor).first {
                logger.debug("[UserStore] SwiftData fetch successful. Existing user found (Name: \(existingUser.name ?? "N/A"), Email: \(existingUser.email ?? "N/A")).")
                var userNeedsSave = false
                if let newEmail = email, !newEmail.isEmpty, existingUser.email != newEmail {
                    existingUser.email = newEmail
                    logger.info("[UserStore] Updating email for user \(userId.prefix(8))... from '\(existingUser.email ?? "nil")' to '\(newEmail)'")
                    userNeedsSave = true
                } else if email != nil && existingUser.email == nil {
                    existingUser.email = email
                    logger.info("[UserStore] Setting email for user \(userId.prefix(8))... to '\(email!)' (was nil)")
                    userNeedsSave = true
                }

                if let personName = fullName {
                    let formattedName = PersonNameComponentsFormatter().string(from: personName)
                    if !formattedName.isEmpty, existingUser.name != formattedName {
                        existingUser.name = formattedName
                        logger.info("[UserStore] Updating name for user \(userId.prefix(8))... from '\(existingUser.name ?? "nil")' to '\(formattedName)'")
                        userNeedsSave = true
                    } else if !formattedName.isEmpty && existingUser.name == nil {
                        existingUser.name = formattedName
                        logger.info("[UserStore] Setting name for user \(userId.prefix(8))... to '\(formattedName)' (was nil)")
                        userNeedsSave = true
                    }
                }
                
                if userNeedsSave {
                    logger.debug("[UserStore] Attempting to save updated existing user to SwiftData.")
                    try modelContext.save()
                    logger.debug("[UserStore] SwiftData save successful for updated existing user.")
                } else {
                    logger.debug("[UserStore] No updates needed for existing user's name/email based on provided data.")
                }
                userToSet = existingUser

            } else {
                logger.debug("[UserStore] SwiftData fetch successful. No existing user found.")
                let newUser = User(appleUserId: userId)
                var newUserName: String? = nil
                if let personName = fullName {
                    let formattedName = PersonNameComponentsFormatter().string(from: personName)
                    if !formattedName.isEmpty {
                        newUserName = formattedName
                    }
                }
                newUser.name = newUserName
                newUser.email = email

                logger.info("[UserStore] Creating new user. Initial Name: \(newUser.name ?? "nil"), Initial Email: \(newUser.email ?? "nil")")
                newUser.isOnboardingComplete = false

                logger.debug("[UserStore] Attempting to insert and save new user to SwiftData.")
                modelContext.insert(newUser)
                try modelContext.save()
                logger.debug("[UserStore] SwiftData insert and save successful for new user.")
                userToSet = newUser
            }
            
            logger.info("[UserStore] Setting currentAppleUser. UserID: \(userToSet?.appleUserId?.prefix(8) ?? "N/A"), Name: \(userToSet?.name ?? "N/A"), Email: \(userToSet?.email ?? "N/A")")
            self.currentAppleUser = userToSet

        } catch {
            let errorMsg = "Failed to fetch or create user (userId: \(userId.prefix(8))...): \(error.localizedDescription)"
            logger.error("\(errorMsg)")
            ErrorManager.shared.presentAlert(title: "Profile Error", message: "Could not load or create your user profile. Please try again.")
        }
        logger.debug("[UserStore] Finished fetchOrCreateUser for userId (prefix: \(userId.prefix(8))...).")
    }

    func signOut() {
        logger.info("Sign out initiated.")
        if let userId = currentAppleUser?.appleUserId {
            logger.info("Signing out user (prefix: \(userId.prefix(8))...).")
        }

        if deleteUserIdFromKeychain() {
            logger.info("Apple User ID removed from Keychain.")
        } else {
            logger.error("Failed to remove Apple User ID from Keychain during sign out.")
        }
        
        self.currentAppleUser = nil
        logger.info("User signed out from app state. currentAppleUser is nil.")
    }

    func attemptToLoadUserFromStorage() {
        logger.debug("[AuthLoad] Starting attemptToLoadUserFromStorage.")
        logger.info("[AuthLoad] Attempting to load user from stored Apple ID in Keychain and then SwiftData.")
        
        guard let modelContext = modelContext else {
            logger.error("[AuthLoad] ModelContext not available. Cannot load user.")
            self.currentAppleUser = nil
            return
        }

        guard let userId = loadUserIdFromKeychain() else {
            logger.info("[AuthLoad] No stored Apple User ID found in Keychain. User remains signed out.")
            self.currentAppleUser = nil
            logger.debug("[AuthLoad] Finished attemptToLoadUserFromStorage: no user ID in Keychain.")
            return
        }
        
        logger.info("[AuthLoad] Found stored Apple User ID (prefix: \(userId.prefix(8))...) in Keychain. Now checking SwiftData.")
        
        let fetchDescriptor = FetchDescriptor<User>(predicate: #Predicate { $0.appleUserId == userId })
        do {
            if let existingUser = try modelContext.fetch(fetchDescriptor).first {
                logger.info("[AuthLoad] User (prefix: \(userId.prefix(8))...) found in SwiftData. Setting as current user. Name: \(existingUser.name ?? "N/A"), Email: \(existingUser.email ?? "N/A")")
                self.currentAppleUser = existingUser // This will trigger the didSet
                
                if existingUser.name == nil || existingUser.name!.isEmpty {
                    logger.warning("[AuthLoad] User (prefix: \(userId.prefix(8))...) has a missing name in their profile. Consider prompting for profile completion.")
                }

                // if existingUser.isOnboardingComplete && HealthKitManager.shared.isAuthorized { ... }
            } else {
                logger.info("[AuthLoad] UserID (prefix: \(userId.prefix(8))...) found in Keychain, but NO matching user in SwiftData. Clearing Keychain and will require sign-in flow.")
                _ = deleteUserIdFromKeychain() // Ensure result is handled or explicitly ignored
                self.currentAppleUser = nil
            }
        } catch {
            logger.error("[AuthLoad] Error fetching user (prefix: \(userId.prefix(8))...) from SwiftData: \(error.localizedDescription). User remains signed out.")
            self.currentAppleUser = nil
            ErrorManager.shared.presentAlert(title: "Profile Error", message: "Could not load or create your user profile. Please try again.")
        }
        logger.debug("[AuthLoad] Finished attemptToLoadUserFromStorage.")
    }
    
    private func fetchHealthDataForCurrentUserIfNeeded(user: User) async {
      
        guard HealthKitManager.shared.isAuthorized else {
            logger.info("[AuthManager] HealthKit not yet authorized. Will not fetch profile data at this moment for user \(user.appleUserId?.prefix(8) ?? "N/A").")
            return
        }
        
        guard user.isOnboardingComplete else {
            logger.info("[AuthManager] Onboarding not complete for user \(user.appleUserId?.prefix(8) ?? "N/A"). Will not fetch profile data.")
            return
        }

        logger.info("[AuthManager] User \(user.appleUserId?.prefix(8) ?? "N/A") logged in, onboarding complete, and HealthKit authorized. Triggering full profile data fetch from HealthKitManager.")
        HealthKitManager.shared.fetchAllUserProfileData()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let window = UIWindow.current {
            logger.info("Providing presentation anchor window.")
            return window
        }
        let errorMsg = "No window available for ASAuthorizationController presentation. This is a critical issue."
        logger.critical("\(errorMsg)")
        fatalError(errorMsg)
    }
    
    func refreshCurrentAppleUser() {
        logger.info("Refresh current Apple User data initiated.")
        guard let modelContext = modelContext else {
            logger.error("Cannot refresh user: ModelContext is not available.")
            ErrorManager.shared.presentAlert(title: "Refresh Error", message: "Could not refresh user data: configuration error.")
            return
        }
        
        guard let userId = self.currentAppleUser?.appleUserId ?? loadUserIdFromKeychain() else {
            logger.warning("Cannot refresh user: User ID not available from current session or Keychain.")
            if self.currentAppleUser != nil {
                signOut()
            }
            ErrorManager.shared.presentAlert(title: "Session Error", message: "Your session data seems to be inconsistent. Please try signing out and signing back in.")
            return
        }
        
        logger.info("Refreshing user profile for userId (prefix: \(userId.prefix(8))...).")
        let fetchDescriptor = FetchDescriptor<User>(predicate: #Predicate { $0.appleUserId == userId })
        do {
            if let refreshedUser = try modelContext.fetch(fetchDescriptor).first {
                self.currentAppleUser = refreshedUser
                logger.info("AuthenticationManager: currentAppleUser refreshed for \(userId.prefix(8))...")
            } else {
                let errorMsg = "User data not found in database during refresh for ID (prefix: \(userId.prefix(8))...)."
                logger.error("\(errorMsg)")
                ErrorManager.shared.presentAlert(title: "Profile Refresh Error", message: "An error occurred while refreshing your profile.")
            }
        } catch {
            let errorMsg = "Error refreshing currentAppleUser (userId: \(userId.prefix(8))...): \(error.localizedDescription)"
            logger.error("\(errorMsg)")
            ErrorManager.shared.presentAlert(title: "Profile Refresh Error", message: "An error occurred while refreshing your profile.")
        }
    }

    private func saveUserIdToKeychain(_ userId: String) -> Bool {
        logger.debug("[Keychain] Starting saveUserIdToKeychain for userId (prefix: \(userId.prefix(8))...).")
        guard let data = userId.data(using: .utf8) else {
            logger.error("Keychain: Failed to convert userId to Data for saving.")
            logger.debug("[Keychain] Finished saveUserIdToKeychain: data conversion failed.")
            return false
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: appleUserIdKeychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        logger.debug("[Keychain] Attempting SecItemDelete for existing item.")
        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            logger.warning("Keychain: Failed to delete existing userId before saving. Status: \(deleteStatus), Error: \(SecCopyErrorMessageString(deleteStatus, nil) ?? "Unknown error" as CFString)")
        } else {
            logger.debug("[Keychain] SecItemDelete successful or item not found.")
        }
        logger.debug("[Keychain] Attempting SecItemAdd.")
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus == errSecSuccess {
            logger.info("Keychain: Successfully saved userId (prefix: \(userId.prefix(8))...).")
            logger.debug("[Keychain] Finished saveUserIdToKeychain: success.")
            return true
        } else {
            logger.error("Keychain: Failed to save userId (prefix: \(userId.prefix(8))...). Status: \(addStatus), Error: \(SecCopyErrorMessageString(addStatus, nil) ?? "Unknown error" as CFString)")
            logger.debug("[Keychain] Finished saveUserIdToKeychain: add failed.")
            return false
        }
    }

    private func loadUserIdFromKeychain() -> String? {
        logger.debug("[Keychain] Starting loadUserIdFromKeychain.")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: appleUserIdKeychainAccount,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        logger.debug("[Keychain] Attempting SecItemCopyMatching.")
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess {
            logger.debug("[Keychain] SecItemCopyMatching successful.")
            if let retrievedData = dataTypeRef as? Data,
               let userId = String(data: retrievedData, encoding: .utf8) {
                logger.info("Keychain: Successfully loaded userId (prefix: \(userId.prefix(8))...).")
                logger.debug("[Keychain] Finished loadUserIdFromKeychain: success, userId found.")
                return userId
            } else {
                logger.error("Keychain: Failed to convert retrieved Keychain data to String. Data might be corrupted.")
                _ = deleteUserIdFromKeychain()
                logger.debug("[Keychain] Finished loadUserIdFromKeychain: data conversion failed.")
                return nil
            }
        } else if status == errSecItemNotFound {
            logger.info("Keychain: userId not found (errSecItemNotFound).")
            logger.debug("[Keychain] Finished loadUserIdFromKeychain: item not found.")
            return nil
        } else {
            logger.error("Keychain: Failed to load userId. Status: \(status), Error: \(SecCopyErrorMessageString(status, nil) ?? "Unknown error" as CFString)")
            logger.debug("[Keychain] Finished loadUserIdFromKeychain: SecItemCopyMatching failed with status \(status).")
            return nil
        }
    }

    private func deleteUserIdFromKeychain() -> Bool {
        logger.debug("[Keychain] Starting deleteUserIdFromKeychain.")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: appleUserIdKeychainAccount
        ]
        logger.debug("[Keychain] Attempting SecItemDelete.")
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            logger.info("Keychain: Successfully deleted userId (or it was not found). Status: \(status)")
            logger.debug("[Keychain] Finished deleteUserIdFromKeychain: success or not found.")
            return true
        } else {
            logger.error("Keychain: Failed to delete userId. Status: \(status), Error: \(SecCopyErrorMessageString(status, nil) ?? "Unknown error" as CFString)")
            logger.debug("[Keychain] Finished deleteUserIdFromKeychain: delete failed with status \(status).")
            return false
        }
    }
}

extension UIWindow {
    static var current: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ??
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first
    }
}
