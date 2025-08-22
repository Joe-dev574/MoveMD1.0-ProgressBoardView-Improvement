//
//  MoveMD1_0App.swift
//  MoveMD1.0
//
//  Created by Joseph DeWeese on 5/6/25.

import SwiftUI
import SwiftData
import UserNotifications

@main
struct MoveMD1_0App: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var errorManager = ErrorManager.shared

    @AppStorage("appearanceSetting") private var appearanceSetting: AppearanceSetting = .system


    let modelContainer: ModelContainer
    @State private var managersConfigured = false

    init() {
        do {
            modelContainer = try ModelContainer(for: Workout.self, User.self, Category.self, Exercise.self, History.self, SplitTime.self)
          
            populateCategories(context: modelContainer.mainContext)
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
        print("[App init] ModelContainer initialized.")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(healthKitManager)
                .environmentObject(errorManager) 
                .preferredColorScheme(appearanceSetting.colorScheme)
                .onAppear {
                    if !managersConfigured {
                        authManager.configureWithModelContext(modelContainer.mainContext)
                        healthKitManager.configureWithModelContext(modelContainer.mainContext)
                        healthKitManager.setCurrentAppleUserId(authManager.currentAppleUser?.appleUserId)
                        
                        managersConfigured = true
                        print("[App onAppear] Core managers configured.")
                    }
                }
                .alert(item: $errorManager.currentAlert) { appAlert in
                    if let secondaryButton = appAlert.secondaryButton {
                        return Alert(title: Text(appAlert.title),
                                     message: Text(appAlert.message),
                                     primaryButton: appAlert.primaryButton,
                                     secondaryButton: secondaryButton)
                    } else {
                        return Alert(title: Text(appAlert.title),
                                     message: Text(appAlert.message),
                                     dismissButton: appAlert.primaryButton) 
                    }
                }
        }
        .modelContainer(modelContainer)
    }
    
    func populateCategories(context: ModelContext) {
        print("[populateCategories] Checking if initial category population is needed.")
        let fetchDescriptor = FetchDescriptor<Category>()
        
        guard let count = try? context.fetchCount(fetchDescriptor), count == 0 else {
            print("[populateCategories] Categories already exist (count: \( (try? context.fetchCount(fetchDescriptor)) ?? -1 )). Skipping initial population.")
            return
        }
        
        print("[populateCategories] Store is empty. Populating all initial categories.")
        let categories = [
            Category(categoryName: "HIIT", symbol: "dumbbell.fill", categoryColor: .HIIT),
            Category(categoryName: "Strength", symbol: "figure.strengthtraining.traditional", categoryColor: .STRENGTH),
            Category(categoryName: "Outdoor Run", symbol: "figure.run", categoryColor: .RUN),
            Category(categoryName: "Yoga", symbol: "figure.yoga", categoryColor: .YOGA),
            Category(categoryName: "Cycling", symbol: "figure.outdoor.cycle", categoryColor: .CYCLING),
            Category(categoryName: "Swimming", symbol: "figure.pool.swim", categoryColor: .SWIMMING),
            Category(categoryName: "Wrestling", symbol: "figure.wrestling", categoryColor: .GRAPPLING),
            Category(categoryName: "Recovery", symbol: "figure.mind.and.body", categoryColor: .RECOVERY),
            Category(categoryName: "Walk", symbol: "figure.walk.motion", categoryColor: .WALK),
            Category(categoryName: "Stretch", symbol: "figure.cooldown", categoryColor: .STRETCH),
            Category(categoryName: "Cross-Train", symbol: "figure.cross.training", categoryColor: .CROSSTRAIN),
            Category(categoryName: "Power", symbol: "figure.strengthtraining.traditional", categoryColor: .POWER),
            Category(categoryName: "Pilates", symbol: "figure.pilates", categoryColor: .PILATES),
            Category(categoryName: "Cardio", symbol: "figure.mixed.cardio", categoryColor: .CARDIO),
            Category(categoryName: "Test", symbol: "stopwatch", categoryColor: .TEST)
        ]
        
        for category in categories {
            context.insert(category)
        }
        
        do {
            try context.save()
            print("[populateCategories] Successfully populated all initial categories.")
        } catch {
            print("Failed to save initial categories during full population: \(error)")
        }
        print("[populateCategories] Finished initial category population.")
    }
}
