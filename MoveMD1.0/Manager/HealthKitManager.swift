//  HealthKitManager.swift
//  MoveMD1.0
//
//  Created by Joseph DeWeese on 5/11/25.
//

import HealthKit
import SwiftData
import os.log
// import MoveMD1_0 // Keep this commented or removed for now

enum HealthKitError: LocalizedError {
    case healthDataUnavailable
    case authorizationFailed(String)
    case invalidWorkoutDuration
    case workoutSaveFailed(String)
    case heartRateDataUnavailable
    case appPurchaseRequired

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "HealthKit is not available on this device."
        case .authorizationFailed(let message):
            return "Failed to authorize HealthKit: \(message)"
        case .invalidWorkoutDuration:
            return "Invalid workout duration."
        case .workoutSaveFailed(let message):
            return "Failed to save workout to HealthKit: \(message)"
        case .heartRateDataUnavailable:
            return "Heart rate data is not available."
        case .appPurchaseRequired:
            return "Full app purchase required to save workouts to HealthKit after trial."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .healthDataUnavailable:
            return "Please ensure your device supports HealthKit."
        case .authorizationFailed:
            return "Please enable HealthKit permissions in the Health app."
        case .invalidWorkoutDuration, .workoutSaveFailed, .heartRateDataUnavailable:
            return "Please try again or contact support if the issue persists."
        case .appPurchaseRequired:
            return "Please purchase the full app from the settings or purchase screen to continue saving workouts."
        }
    }
}

@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    @Published var isAuthorized: Bool = false
    private var currentAppleUserId: String?
    private var modelContext: ModelContext?
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.movemd.default.subsystem", category: "HealthKitManager")
    
    private init() {
        logger.info("Initializing HealthKitManager")
    }
    
    func configureWithModelContext(_ context: ModelContext) {
        self.modelContext = context
        updateCurrentAuthorizationStatus()
        logger.info("HealthKitManager configured with ModelContext. Current auth status updated.")
    }
    
    func setCurrentAppleUserId(_ appleUserId: String?) {
        self.currentAppleUserId = appleUserId
        if let id = appleUserId {
            logger.info("HealthKitManager: Current Apple User ID set to \(id.prefix(8))")
        } else {
            logger.info("HealthKitManager: Current Apple User ID cleared.")
        }
    }
    
    private func fetchUser() -> User? { // Ensure User? not ModelContext.User?
        guard let context = modelContext, let appleUserId = currentAppleUserId else {
            logger.error("ModelContext or currentAppleUserId not available in HealthKitManager for fetchUser")
            return nil
        }
        let predicate = #Predicate<User> { $0.appleUserId == appleUserId } // Ensure User, not ModelContext.User
        let descriptor = FetchDescriptor<User>(predicate: predicate) // Ensure User, not ModelContext.User
        do {
            let users = try context.fetch(descriptor)
            if let user = users.first {
                logger.info("User for Apple ID \(appleUserId.prefix(8)) fetched in HealthKitManager.")
                return user
            } else {
                logger.info("User for Apple ID \(appleUserId.prefix(8)) not found in HealthKitManager.")
                return nil
            }
        } catch {
            logger.error("Failed to fetch user with Apple ID \(appleUserId.prefix(8)): \(error.localizedDescription)")
            return nil
        }
    }
    
    func updateCurrentAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            DispatchQueue.main.async { self.isAuthorized = false }
            return
        }
        let workoutType = HKObjectType.workoutType()
        healthStore.getRequestStatusForAuthorization(toShare: [workoutType], read: []) { [weak self] (status, error) in
            DispatchQueue.main.async {
                if let error = error {
                    self?.logger.error("Error checking HealthKit request status: \(error.localizedDescription)")
                    self?.isAuthorized = false
                    return
                }
                switch status {
                case .unnecessary:
                    self?.logger.info("HealthKit authorization status for workouts: unnecessary (likely already authorized).")
                    self?.isAuthorized = true
                case .shouldRequest:
                    self?.logger.info("HealthKit authorization status for workouts: shouldRequest (not yet prompted or user can change).")
                    self?.isAuthorized = false
                case .unknown:
                    self?.logger.info("HealthKit authorization status for workouts: unknown.")
                    self?.isAuthorized = false
                @unknown default:
                    self?.logger.info("HealthKit authorization status for workouts: unknown default case.")
                    self?.isAuthorized = false
                }
            }
        }
    }

    func requestHealthKitPermissions(completion: @escaping (Bool, Error?) -> Void = { _, _ in }) {
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.error("HealthKit is not available on this device.")
            DispatchQueue.main.async {
                self.isAuthorized = false
                completion(false, HealthKitError.healthDataUnavailable)
            }
            return
        }
        let typesToShare: Set<HKSampleType> = [ // Explicitly HKSampleType for clarity
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)! // Add this line
        ]
        let typesToRead: Set = [
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
            HKQuantityType.quantityType(forIdentifier: .height)!,
            HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth)!,
            HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex)!,
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isAuthorized = success
                if success {
                    self?.logger.info("HealthKit authorization successful via requestHealthKitPermissions for types: \(typesToShare.map { $0.identifier }.joined(separator: ", "))")
                } else {
                    let message = error?.localizedDescription ?? "Unknown error"
                    self?.logger.error("HealthKit authorization failed via requestHealthKitPermissions: \(message)")
                }
                completion(success, error)
            }
        }
    }
    
    func saveWorkout(_ workout: Workout, history: History, samples: [HKSample]) async throws -> Bool { // Ensure Workout, History
        guard isAuthorized else {
            logger.error("Cannot save workout: HealthKit not authorized.")
            throw HealthKitError.authorizationFailed("Permission not granted to save workout.")
        }
        guard PurchaseManager.shared.isUnlocked else {
            logger.error("App purchase required for saving workout (trial ended or not purchased)")
            throw HealthKitError.appPurchaseRequired
        }
        
        guard history.lastSessionDuration > 0 else {
            logger.error("Invalid workout duration: \(history.lastSessionDuration)")
            throw HealthKitError.invalidWorkoutDuration
        }
        
        let workoutConfiguration = HKWorkoutConfiguration()
        if let category = workout.category {
            workoutConfiguration.activityType = category.categoryColor.hkActivityType
            logger.info("Mapping workout to HKActivityType: \(category.categoryName) -> \(String(describing: workoutConfiguration.activityType))")
        } else {
            workoutConfiguration.activityType = .other
            logger.info("Workout has no category, defaulting to HKActivityType: .other")
        }
        
        let startDate = history.date
        let endDate = startDate.addingTimeInterval(history.lastSessionDuration * 60.0)
        
        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: workoutConfiguration,
            device: nil
        )
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: startDate) { success, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.workoutSaveFailed(error.localizedDescription))
                    return
                }
                guard success else {
                    continuation.resume(throwing: HealthKitError.workoutSaveFailed("Failed to begin workout collection"))
                    return
                }
                continuation.resume(returning: ())
            }
        }

        if !samples.isEmpty {
            logger.info("Adding \(samples.count) samples to the HealthKit workout builder. Sample types: \(samples.map { $0.sampleType.identifier }.joined(separator: ", "))")
            for sample in samples {
                if let quantitySample = sample as? HKQuantitySample {
                    logger.debug("-- Sample: \(quantitySample.quantityType.identifier), Value: \(quantitySample.quantity), Start: \(quantitySample.startDate), End: \(quantitySample.endDate)")
                    if quantitySample.sampleType == HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                        logger.info("-----> Found Active Energy Sample to add: \(quantitySample.quantity)")
                    }
                } else {
                    logger.debug("-- Sample: \(sample.sampleType.identifier), Start: \(sample.startDate), End: \(sample.endDate)")
                }
            }
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                builder.add(samples) { success, error in
                    if let error = error {
                        self.logger.error("Failed to add samples to workout builder: \(error.localizedDescription)")
                        continuation.resume(throwing: HealthKitError.workoutSaveFailed("Failed to add samples: \(error.localizedDescription)"))
                        return
                    }
                    guard success else {
                        self.logger.error("Failed to add samples to workout builder (success=false). This is critical for Active Energy.")
                        continuation.resume(throwing: HealthKitError.workoutSaveFailed("Failed to add samples (success=false)"))
                        return
                    }
                    self.logger.info("Successfully ADDED \(samples.count) samples to HealthKit WorkoutBuilder.")
                    continuation.resume(returning: ())
                }
            }
        } else {
            logger.info("No detailed samples provided to add to the HealthKit workout (so no Active Energy will be added).")
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: endDate) { success, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.workoutSaveFailed(error.localizedDescription))
                    return
                }
                guard success else {
                    continuation.resume(throwing: HealthKitError.workoutSaveFailed("Failed to end workout collection"))
                    return
                }
                continuation.resume(returning: ())
            }
        }
        
        do {
            let savedWorkout = try await builder.finishWorkout()
            logger.info("Successfully saved workout to HealthKit: \(workout.title)")
            return savedWorkout != nil
        } catch {
            logger.error("Failed to save workout to HealthKit: \(error.localizedDescription)")
            throw HealthKitError.workoutSaveFailed(error.localizedDescription)
        }
    }
    
    func fetchAllUserProfileData() {
        guard isAuthorized else {
            logger.warning("Cannot fetch user profile data: HealthKit is not authorized.")
            return
        }
        logger.info("Attempting to fetch all user profile data from HealthKit...")
        
        fetchDateOfBirthAndAge { [weak self] age, error in
             guard let self else { return }
             DispatchQueue.main.async {
                 if let error = error {
                     self.logger.error("Failed to fetch age: \(error.localizedDescription)")
                     return
                 }
                 if let age = age, let user = self.fetchUser() { // fetchUser() correctly returns User?
                     if user.age != age {
                         user.age = age
                         self.saveContext()
                         self.logger.info("Updated user age: \(age)")
                     } else {
                         self.logger.trace("Fetched age (\(age)) matches existing user data. No update needed.")
                     }
                 } else if age == nil {
                     self.logger.info("No age data found in HealthKit.")
                 } else if self.fetchUser() == nil { // Check against nil
                      self.logger.warning("No user found to update age.")
                 }
             }
         }

        fetchLatestRestingHeartRate { [weak self] heartRate, error in
             guard let self else { return }
             DispatchQueue.main.async {
                 if let error = error {
                     self.logger.error("Failed to fetch resting heart rate: \(error.localizedDescription)")
                     return
                 }
                 if let heartRate = heartRate, let user = self.fetchUser() {
                     if user.restingHeartRate != heartRate {
                         user.restingHeartRate = heartRate
                         self.saveContext()
                         self.logger.info("Updated user resting heart rate: \(heartRate) bpm")
                     } else {
                         self.logger.trace("Fetched RHR (\(heartRate)) matches existing user data. No update needed.")
                     }
                 } else if heartRate == nil {
                      self.logger.info("No resting heart rate data found in HealthKit.")
                 } else if self.fetchUser() == nil {
                      self.logger.warning("No user found to update resting heart rate.")
                 }
             }
         }

        fetchLatestWeight { [weak self] weightKg, error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    self.logger.error("Failed to fetch weight: \(error.localizedDescription)")
                    return
                }
                if let weightKg = weightKg, let user = self.fetchUser() {
                    let tolerance = 0.01
                    if abs((user.weight ?? 0.0) - weightKg) > tolerance {
                        user.weight = weightKg
                        self.saveContext()
                        self.logger.info("Updated user weight: \(weightKg) kg")
                    } else {
                         self.logger.trace("Fetched weight (\(weightKg) kg) matches existing user data (within tolerance). No update needed.")
                    }
                } else if weightKg == nil {
                     self.logger.info("No weight data found in HealthKit.")
                } else if self.fetchUser() == nil {
                     self.logger.warning("No user found to update weight.")
                }
            }
        }

        fetchLatestHeight { [weak self] heightMeters, error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    self.logger.error("Failed to fetch height: \(error.localizedDescription)")
                    return
                }
                if let heightMeters = heightMeters, let user = self.fetchUser() {
                     let tolerance = 0.001
                     if abs((user.height ?? 0.0) - heightMeters) > tolerance {
                         user.height = heightMeters
                         self.saveContext()
                         self.logger.info("Updated user height: \(heightMeters) m")
                     } else {
                           self.logger.trace("Fetched height (\(heightMeters) m) matches existing user data (within tolerance). No update needed.")
                     }
                } else if heightMeters == nil {
                     self.logger.info("No height data found in HealthKit.")
                } else if self.fetchUser() == nil {
                     self.logger.warning("No user found to update height.")
                }
            }
        }
    }
    
    func fetchLatestRestingHeartRate(completion: @escaping (Double?, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.error("HealthKit is not available on this device")
            completion(nil, HealthKitError.healthDataUnavailable)
            return
        }
        
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            logger.error("Resting heart rate type is not available")
            completion(nil, HealthKitError.heartRateDataUnavailable)
            return
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            if let error = error {
                self?.logger.error("Failed to fetch resting heart rate: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let sample = samples?.first as? HKQuantitySample else {
                self?.logger.info("No resting heart rate samples found")
                completion(nil, nil)
                return
            }
            
            let heartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            self?.logger.info("Fetched resting heart rate: \(heartRate) bpm")
            completion(heartRate, nil)
        }
        
        logger.debug("Executing resting heart rate query")
        healthStore.execute(query)
    }
    
    func fetchDateOfBirthAndAge(completion: @escaping (Int?, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.error("HealthKit is not available on this device")
            completion(nil, HealthKitError.healthDataUnavailable)
            return
        }
        
        do {
            let dateOfBirthComponents = try healthStore.dateOfBirthComponents()
            guard let birthDate = dateOfBirthComponents.date else {
                logger.error("No birth date available in HealthKit")
                completion(nil, NSError(domain: "HealthKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "No birth date available"]))
                return
            }
            
            let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
            logger.info("Fetched user age: \(age ?? -1)")
            completion(age, nil)
        } catch {
            logger.error("Failed to fetch date of birth: \(error.localizedDescription)")
            completion(nil, error)
        }
    }
    
    func fetchLatestWeight(completion: @escaping (Double?, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.error("[fetchLatestWeight] HealthKit is not available.")
            completion(nil, HealthKitError.healthDataUnavailable)
            return
        }
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            logger.error("[fetchLatestWeight] Body mass type is not available.")
            completion(nil, NSError(domain: "HealthKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Body mass type unavailable"]))
            return
        }

        logger.debug("[fetchLatestWeight] Preparing HKSampleQuery for bodyMass.")
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            if let error = error {
                self?.logger.error("[fetchLatestWeight] Failed query: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            guard let sample = samples?.first as? HKQuantitySample else {
                self?.logger.info("[fetchLatestWeight] No bodyMass samples found in HealthKit.")
                completion(nil, nil)
                return
            }
            let weightInKg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            self?.logger.info("[fetchLatestWeight] Successfully fetched weight: \(weightInKg) kg from HealthKit.")
            completion(weightInKg, nil)
        }
        logger.debug("[fetchLatestWeight] Executing HKSampleQuery for bodyMass.")
        healthStore.execute(query)
    }

    func fetchLatestHeight(completion: @escaping (Double?, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.error("[fetchLatestHeight] HealthKit is not available.")
            completion(nil, HealthKitError.healthDataUnavailable)
            return
        }
        guard let heightType = HKObjectType.quantityType(forIdentifier: .height) else {
            logger.error("[fetchLatestHeight] Height type is not available.")
            completion(nil, NSError(domain: "HealthKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Height type unavailable"]))
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: heightType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            if let error = error {
                self?.logger.error("[fetchLatestHeight] Failed query: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            guard let sample = samples?.first as? HKQuantitySample else {
                self?.logger.info("[fetchLatestHeight] No samples found.")
                completion(nil, nil)
                return
            }
            let heightInMeters = sample.quantity.doubleValue(for: .meter())
            self?.logger.info("[fetchLatestHeight] Fetched: \(heightInMeters) m")
            completion(heightInMeters, nil)
        }
        logger.debug("[fetchLatestHeight] Executing query.")
        healthStore.execute(query)
    }

    private func saveContext() {
        guard let context = modelContext else {
            logger.error("ModelContext is nil. Cannot save HealthKit updates.")
            return
        }
        logger.info("[saveContext] ModelContext has changes. Attempting to save updates from HealthKit.")
        if context.hasChanges {
            logger.info("[saveContext] ModelContext has changes. Attempting to save updates from HealthKit.")
        } else {
            logger.trace("[saveContext] No changes detected in ModelContext before potential save operation for HealthKit data.")
        }

        do {
            try context.save()
            logger.info("Saved ModelContext after HealthKitManager operations (update user from HealthKit or other metric calculations).")
        } catch {
            logger.error("Failed to save ModelContext after HealthKit update: \(error.localizedDescription)")
        }
    }

    func calculateIntensityScore(dateInterval: DateInterval, restingHeartRate: Double?, completion: @escaping (Double?, Error?) -> Void) {
        logger.info("[HealthKitManager] calculateIntensityScore called (Placeholder).")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            let dummyScore = Double.random(in: 60...90)
            self.logger.info("[HealthKitManager] Placeholder Intensity Score calculated: \(dummyScore)")
            completion(dummyScore, nil)
        }
    }

    func calculateTimeInZones(dateInterval: DateInterval, maxHeartRate: Double?, completion: @escaping ([Int: Double]?, Int?, Error?) -> Void) {
        logger.info("[HealthKitManager] calculateTimeInZones called (Placeholder).")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            let dummyZones: [Int: Double] = [
                1: Double.random(in: 1...5) * 60,
                2: Double.random(in: 5...10) * 60,
                3: Double.random(in: 10...15) * 60,
                4: Double.random(in: 2...8) * 60,
                5: Double.random(in: 0...3) * 60
            ]
            let dummyDominantZone = dummyZones.max(by: { $0.value < $1.value })?.key
            self.logger.info("[HealthKitManager] Placeholder Time in Zones calculated: \(dummyZones), Dominant: \(String(describing: dummyDominantZone))")
            completion(dummyZones, dummyDominantZone, nil)
        }
    }
    
    func calculateProgressPulseScore(personalBest: Double, currentDuration: Double, workoutsPerWeek: Int, targetWorkoutsPerWeek: Int, dominantZone: Int?) -> Double? {
         logger.info("[HealthKitManager] calculateProgressPulseScore called.")
         var score = 50.0 // Base score

         // Duration comparison component
         // If current workout is faster than (or equal to) personal best, award points.
         // Assumes personalBest is the SHORTEST duration.
         if currentDuration <= personalBest {
             score += 15
             logger.debug("[ProgressPulse] Beat or matched PR: +15 points. Current: \(currentDuration), PB: \(personalBest)")
         } else {
             // Optional: Penalize slightly or give fewer points if slower than PR but still completed
             // For now, no change if slower.
             logger.debug("[ProgressPulse] Slower than PR. Current: \(currentDuration), PB: \(personalBest)")
         }

         // Consistency component (frequency)
         let frequencyPoints = Double(min(workoutsPerWeek, targetWorkoutsPerWeek) * 5)
         score += frequencyPoints
         logger.debug("[ProgressPulse] Frequency points: +\(frequencyPoints) (Workouts this week: \(workoutsPerWeek), Target: \(targetWorkoutsPerWeek))")

         // Intensity component (dominant zone)
         if let zone = dominantZone {
            if zone >= 4 { // Zone 4 (Hard) or 5 (Maximum)
                score += 10
                logger.debug("[ProgressPulse] High intensity (Zone \(zone)): +10 points")
            } else if zone == 3 { // Zone 3 (Moderate)
                score += 5
                logger.debug("[ProgressPulse] Moderate intensity (Zone \(zone)): +5 points")
            } else {
                logger.debug("[ProgressPulse] Low intensity (Zone \(zone)): +0 points")
            }
         } else {
             logger.debug("[ProgressPulse] Dominant zone not available: +0 points for intensity.")
         }


         let finalScore = min(max(score, 0), 100) // Clamp score between 0 and 100
         logger.info("[HealthKitManager] Progress Pulse score calculated: \(finalScore)")
         return finalScore
    }

    struct HKFetchedWorkout: Identifiable {
        let id: UUID
        let activityType: HKWorkoutActivityType
        let startDate: Date
        let endDate: Date
        let duration: TimeInterval
        let totalEnergyBurned: Double? // in kilocalories
        let totalDistance: Double? // in meters (or a relevant unit)
        let sourceName: String
    }

    func fetchWorkoutsFromHealthKit(from queryStartDate: Date = .distantPast, to queryEndDate: Date = .now) async throws -> [HKFetchedWorkout] {
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.error("[fetchWorkoutsFromHealthKit] HealthKit is not available.")
            throw HealthKitError.healthDataUnavailable
        }
        
        // Ensure typesToRead in requestHealthKitPermissions includes HKObjectType.workoutType()
        // Based on previous context, this is already included.

        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: queryStartDate, end: queryEndDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        logger.info("[fetchWorkoutsFromHealthKit] Fetching workouts from \(queryStartDate) to \(queryEndDate).")

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
                guard let strongSelf = self else {
                    continuation.resume(throwing: NSError(domain: "HealthKitManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Self deallocated"]))
                    return
                }

                if let error = error {
                    strongSelf.logger.error("[fetchWorkoutsFromHealthKit] Error fetching workouts: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }

                guard let workouts = samples as? [HKWorkout] else {
                    strongSelf.logger.info("[fetchWorkoutsFromHealthKit] No workouts found or samples are not HKWorkout type.")
                    continuation.resume(returning: [])
                    return
                }

                let fetchedWorkouts = workouts.map { workout -> HKFetchedWorkout in
                    let energyBurned = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                    let distance = workout.totalDistance?.doubleValue(for: .meter()) // Defaulting to meters, adjust unit if needed

                    return HKFetchedWorkout(
                        id: workout.uuid,
                        activityType: workout.workoutActivityType,
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        duration: workout.duration,
                        totalEnergyBurned: energyBurned,
                        totalDistance: distance,

                        sourceName: workout.sourceRevision.source.name
                    )
                }
                strongSelf.logger.info("[fetchWorkoutsFromHealthKit] Successfully fetched \(fetchedWorkouts.count) workouts.")
                continuation.resume(returning: fetchedWorkouts)
            }
            // Execute the query on healthStore
            self.healthStore.execute(query)
        }
    }
}
