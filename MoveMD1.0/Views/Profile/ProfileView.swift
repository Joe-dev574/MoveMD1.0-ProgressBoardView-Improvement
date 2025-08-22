//
//  ProfileView.swift
//  MoveMD1.0
//
//  Created by Joseph DeWeese on 4/29/25.
//

import SwiftUI
import SwiftData
import PhotosUI
import OSLog

private struct ProfileHeaderView: View {
    @Bindable var user: User
    var themeColor: Color
    @Binding var selectedPhoto: PhotosPickerItem?

    @ViewBuilder
    private var profileImageView: some View {
        if let imageData = user.profileImageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray.opacity(0.5), lineWidth: 1))
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.gray)
        }
    }

    var body: some View {
        VStack {
            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                profileImageView
            }
            .buttonStyle(.plain)
            .padding(.bottom, 5)
            
            TextField("Enter your name", text: Binding(
                get: { user.name ?? "" },
                set: { user.name = $0.isEmpty ? nil : $0 }
            ))
            .font(.title2).bold()
            .foregroundColor(themeColor)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            
            Text(user.email ?? "No email provided")
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
    }
}

private struct ProfileFormContentView: View {
    @Bindable var user: User
    var themeColor: Color
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var selectedProgressSelfieItems: [PhotosPickerItem]
    @Binding var selectedSelfieForDetail: ProgressSelfie?
   

    @Binding var weightString: String
    @Binding var heightString: String
    @Binding var maxHRString: String
    @Binding var isLoadingHealthData: Bool 

    private let fitnessGoals = ["General Fitness", "Weight Loss", "Muscle Gain", "Endurance", "Flexibility"]
    
    private let selfieGridLayout = [
        GridItem(.adaptive(minimum: 100), spacing: 10)
    ]

    var body: some View {
        Form {
            Section {
                ProfileHeaderView(
                    user: user,
                    themeColor: themeColor,
                    selectedPhoto: $selectedPhoto
                )
            }
            .listRowInsets(EdgeInsets())

            Section(header: Text("Fitness Goal").font(.system(size: 18, design: .serif))
                .fontWeight(.semibold)
                .foregroundStyle(themeColor)){
                Picker("Select Goal", selection: Binding(
                    get: { user.fitnessGoal ?? "General Fitness"},
                    set: { user.fitnessGoal = $0 }
                )) {
                    ForEach(fitnessGoals, id: \.self) { goal in
                        Text(goal).tag(goal)
                    }
                }
                .foregroundStyle(.primary)
            }
           
            HealthMetricsSectionView(
                user: user,
                themeColor: themeColor,
                weightString: $weightString,
                heightString: $heightString,
                maxHRString: $maxHRString,
                isLoading: isLoadingHealthData 
            )
            
            Section(header: Text("Progress Pictures").font(.system(size: 18, design: .serif))
                .fontWeight(.semibold)
                .foregroundStyle(themeColor))  {
                if !user.progressSelfies.isEmpty {
                    LazyVGrid(columns: selfieGridLayout, spacing: 10) {
                        ForEach(user.progressSelfies.sorted(by: { $0.dateAdded > $1.dateAdded })) { selfie in
                            VStack {
                                if let uiImage = UIImage(data: selfie.imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .cornerRadius(8)
                                        .clipped()
                                } else {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 100, height: 100)
                                        .cornerRadius(8)
                                        .overlay(Image(systemName: "photo"))
                                }
                                Text(selfie.displayName)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Progress picture from \(selfie.displayName)")
                            .onTapGesture {
                                selectedSelfieForDetail = selfie
                            }
                        }
                    }
                    .padding(.vertical, 5)
                } else {
                    Text("No progress pictures yet. Add some to track your journey!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                PhotosPicker(
                    selection: $selectedProgressSelfieItems,
                    maxSelectionCount: 5,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Add Progress Picture", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var errorManager: ErrorManager
    
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"

    private var themeColor: Color { Color(hex: selectedThemeColorData) ?? .blue }

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedProgressSelfieItems: [PhotosPickerItem] = []
    @State private var presentingSelfieDetail: ProgressSelfie? = nil
    
    @State private var weightString: String = ""
    @State private var heightString: String = ""
    @State private var maxHRString: String = ""

    @State private var isLoadingHealthData: Bool = false

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.movemd.default", category: "ProfileView")

    var body: some View {
        guard let validCurrentUser = authManager.currentAppleUser else {
            let _ = logger.warning("ProfileView body rendered but authManager.currentAppleUser is nil.")
            return AnyView(
                VStack {
                     ProgressView("Loading User Profile...")
                }
            )
        }
        
        let userIdForLog = validCurrentUser.appleUserId ?? "UNKNOWN_ID"
        let logMessage = "ProfileView body rendering for user ID: \(userIdForLog)"
        let _ = logger.debug("\(logMessage)")

        return AnyView(
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [.gray.opacity(0.02), .gray.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                NavigationStack {
                    ProfileFormContentView(
                        user: validCurrentUser,
                        themeColor: themeColor,
                        selectedPhoto: $selectedPhoto,
                        selectedProgressSelfieItems: $selectedProgressSelfieItems,
                        selectedSelfieForDetail: $presentingSelfieDetail,
                        weightString: $weightString,
                        heightString: $heightString,
                        maxHRString: $maxHRString,
                        isLoadingHealthData: $isLoadingHealthData
                    )
                    .navigationTitle("Profile")
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                         ToolbarItemGroup(placement: .confirmationAction) {
                             Button("Save") {
                                 saveProfileData(forUser: validCurrentUser)
                             }
                             .font(.system(size: 15, weight: .semibold, design: .serif))
                         }
                         ToolbarItem(placement: .navigationBarTrailing) {
                             NavigationLink { SettingsView().environmentObject(authManager) }
                             label: { Image(systemName: "gear") }
                         }
                    }
                }
                .tint(themeColor)
                .id(themeColor)
            }
            .task {
                logger.info("ProfileView .task executing.")
                guard let userForTask = authManager.currentAppleUser else {
                    logger.warning(".task: Current Apple User is nil, cannot proceed with health data operations.")
                    return
                }
                updateLocalHealthMetricStrings(fromUser: userForTask)
                
                let isHKAuthorized = HealthKitManager.shared.isAuthorized
                logger.info("Conditions for fetching HK data:  isHKAuthorized=\(isHKAuthorized)")

                if isHKAuthorized {
                    isLoadingHealthData = true
                    logger.info("Fetching HealthKit data...")
                    HealthKitManager.shared.setCurrentAppleUserId(userForTask.appleUserId)
                    
                    HealthKitManager.shared.fetchAllUserProfileData()
                    logger.info("HealthKit data fetch initiated.")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        isLoadingHealthData = false
                        logger.info("HealthKit data loading indicator turned off (simulated).")
                        updateLocalHealthMetricStrings(fromUser: userForTask)
                    }
                } else {
                     logger.info("Skipping HealthKit data fetch due to conditions not met.")
                     isLoadingHealthData = false
                }
            }
             .onChange(of: unitSystem) { _, _ in
                 logger.debug("Unit system changed, updating local strings.")
                 guard let userOnChange = authManager.currentAppleUser else { return }
                 updateLocalHealthMetricStrings(fromUser: userOnChange)
             }
             .onChange(of: selectedPhoto) { _, newPhotoItem in
                 guard let userToUpdate = authManager.currentAppleUser else {
                     print("User signed out before profile image processing.")
                     return
                 }
                 Task {
                     guard let item = newPhotoItem,
                           let originalData = try? await item.loadTransferable(type: Data.self) else {
                         print("Failed to load profile image data or item is nil.")
                         return
                     }
                     if let optimizedData = ImageOptimizer.optimize(imageData: originalData, targetSize: CGSize(width: 512, height: 512)) {
                         await MainActor.run {
                             userToUpdate.profileImageData = optimizedData
                         }
                     } else {
                         await MainActor.run {
                             userToUpdate.profileImageData = originalData
                         }
                         print("Profile image optimization failed, used original.")
                     }
                     logger.debug("Profile photo selected.")
                 }
             }
             .onChange(of: selectedProgressSelfieItems) { _, newItems in
                 guard let userToUpdate = authManager.currentAppleUser else {
                     print("User signed out before progress selfie processing.")
                     return
                 }
                 Task {
                     for item in newItems {
                         do {
                             if let originalImageData = try await item.loadTransferable(type: Data.self) {
                                 if let optimizedImageData = ImageOptimizer.optimize(imageData: originalImageData) {
                                     let newSelfie = ProgressSelfie(imageData: optimizedImageData, dateAdded: Date())
                                     await MainActor.run {
                                         userToUpdate.progressSelfies.append(newSelfie)
                                     }
                                     print("Added new optimized progress selfie: \(newSelfie.displayName)")
                                 } else {
                                     print("Failed to optimize image data for progress selfie. Original size: \(originalImageData.count) bytes.")
                                 }
                             }
                         } catch {
                             print("Failed to load image data for progress selfie: \(error)")
                         }
                     }
                     await MainActor.run {
                         selectedProgressSelfieItems = []
                     }
                     logger.debug("Progress selfies selected.")
                 }
             }
             .onChange(of: validCurrentUser.weight) { oldWeight, newWeight in
                 logger.trace("Detected change in validCurrentUser.weight: \(String(describing: oldWeight)) -> \(String(describing: newWeight))")
                 if !isHealthFieldsEditable() {
                     logger.debug("Weight changed and fields not editable, updating local strings.")
                     updateLocalHealthMetricStrings(fromUser: validCurrentUser)
                 } else {
                      logger.trace("Weight changed but fields are editable, skipping local string update.")
                 }
             }
             .onChange(of: validCurrentUser.height) { oldHeight, newHeight in
                 logger.trace("Detected change in validCurrentUser.height: \(String(describing: oldHeight)) -> \(String(describing: newHeight))")
                  if !isHealthFieldsEditable() {
                      logger.debug("Height changed and fields not editable, updating local strings.")
                      updateLocalHealthMetricStrings(fromUser: validCurrentUser)
                  } else {
                      logger.trace("Height changed but fields are editable, skipping local string update.")
                  }
             }
             .onChange(of: validCurrentUser.restingHeartRate) { oldRHR, newRHR in
                  logger.trace("Detected change in validCurrentUser.restingHeartRate: \(String(describing: oldRHR)) -> \(String(describing: newRHR))")
             }
             .onChange(of: validCurrentUser.maxHeartRate) { oldMaxHR, newMaxHR in
                 logger.trace("Detected change in validCurrentUser.maxHeartRate: \(String(describing: oldMaxHR)) -> \(String(describing: newMaxHR))")
                 if !isHealthFieldsEditable() {
                     logger.debug("MaxHR changed and fields not editable, updating local strings.")
                     updateLocalHealthMetricStrings(fromUser: validCurrentUser)
                 } else {
                      logger.trace("MaxHR changed but fields are editable, skipping local string update.")
                 }
             }
             .sheet(item: $presentingSelfieDetail) { selfieToView in
                 if let user = authManager.currentAppleUser {
                      SelfieDetailView(selfie: selfieToView, user: user, themeColor: themeColor)
                 } else {
                     Text("Error: User data unavailable.")
                 }
             }
        )
    }

    private func isHealthFieldsEditable() -> Bool {
        return !HealthKitManager.shared.isAuthorized
    }

     private func updateLocalHealthMetricStrings(fromUser user: User) {
         if let weightKg = user.weight, !weightKg.isNaN {
             if unitSystem == .imperial {
                 let weightLbs = weightKg * 2.20462
                 weightString = String(format: "%.1f", weightLbs)
             } else {
                 weightString = String(format: "%.1f", weightKg)
             }
         } else {
             weightString = ""
         }

         if let heightMeters = user.height, !heightMeters.isNaN {
             if unitSystem == .imperial {
                 let totalInches = heightMeters * 39.3701
                 let feet = Int(totalInches / 12)
                 let inches = Int(round(totalInches.truncatingRemainder(dividingBy: 12)))
                 heightString = "\(feet)' \(inches)\""
             } else {
                 let heightCm = heightMeters * 100
                 heightString = String(format: "%.0f", heightCm)
             }
         } else {
             heightString = ""
         }

         if let maxHrValue = user.maxHeartRate {
             if !maxHrValue.isNaN {
                 maxHRString = "\(Int(maxHrValue))"
             } else {
                 maxHRString = ""
             }
         } else {
             maxHRString = ""
         }
         print("[ProfileView] Updated local health strings: W: \(weightString), H: \(heightString), MaxHR: \(maxHRString)")
     }

     private func saveProfileData(forUser user: User) {
         if isHealthFieldsEditable() {
             print("[ProfileView Save] Health fields were editable. Parsing from local strings.")
             if let weightValue = Double(weightString) {
                 user.weight = (unitSystem == .imperial) ? (weightValue / 2.20462) : weightValue
                 print("Saving weight: \(user.weight ?? -1) kg from string: \(weightString)")
             } else if weightString.isEmpty { user.weight = nil; print("Clearing weight.") }
             else { print("Invalid weight string: \(weightString)") }

             if unitSystem == .imperial {
                 let components = heightString.replacingOccurrences(of: "\"", with: "")
                                           .components(separatedBy: CharacterSet(charactersIn: "' "))
                                           .filter { !$0.isEmpty }
                 if components.count == 2, let feet = Double(components[0]), let inches = Double(components[1]) {
                     user.height = ((feet * 12) + inches) * 0.0254
                     print("Saving height: \(user.height ?? -1) m from imperial string: \(heightString)")
                 } else if heightString.isEmpty { user.height = nil; print("Clearing height.") }
                 else { print("Invalid imperial height string: \(heightString)") }
             } else {
                 if let heightCm = Double(heightString) {
                     user.height = heightCm / 100.0
                     print("Saving height: \(user.height ?? -1) m from metric string: \(heightString)")
                 } else if heightString.isEmpty { user.height = nil; print("Clearing height.") }
                 else { print("Invalid metric height string: \(heightString)") }
             }

             if let maxHRValue = Int(maxHRString) {
                 user.maxHeartRate = Double(maxHRValue)
                 print("Saving maxHR: \(user.maxHeartRate ?? -1) from string: \(maxHRString)")
             } else if maxHRString.isEmpty { user.maxHeartRate = nil; print("Clearing maxHR.") }
             else { print("Invalid maxHR string: \(maxHRString)") }
         } else {
              print("[ProfileView Save] Health fields were NOT editable. Data from HealthKit is used directly (no manual save needed for these fields).")
         }
         do {
             if modelContext.hasChanges {
                 try modelContext.save()
                 print("Profile (including name, goal, selfies, profile pic) saved successfully. User: \(user.name ?? "N/A")")
                 errorManager.presentAlert(title: "Profile Saved", message: "Your profile information has been updated.")
             } else {
                 print("No changes detected in profile to save.")
                 errorManager.presentAlert(title: "No Changes", message: "There were no changes to save.")
             }
         } catch {
             print("Error saving profile context: \(error)")
             errorManager.presentAlert(title: "Save Error", message: "Could not save your profile changes. Please try again. Error: \(error.localizedDescription)")
         }
     }
}


