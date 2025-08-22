
import SwiftUI
import SwiftData
import HealthKit

struct WorkoutSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var purchaseManager: PurchaseManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var errorManager: ErrorManager
    let workout: Workout
    
    @State private var secondsElapsed: Double = 0.0
    @State private var currentExerciseIndex: Int = 0
    @State private var splitTimes: [SplitTime] = []
    @State private var exercisesCompleted: [Exercise] = []
    @State private var timer: Timer?
    @State private var startDate: Date = .now
    @State private var showMetrics: Bool = false
    @State private var intensityScore: Double?
    @State private var progressPulseScore: Double?
    @State private var dominantZone: Int?
    @State private var finalDisplayedWorkoutDurationSeconds: Double = 0.0
    @State private var collectedHKSamples: [HKSample] = []

    var body: some View {
        ZStack {
            Color.proBackground
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(workout.title)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.top, 8)

                if let category = workout.category {
                    Label(category.categoryName, systemImage: category.symbol)
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundColor(category.categoryColor.color)
                        .padding(.bottom, 4)
                }

                Text(formattedTime(finalDisplayedWorkoutDurationSeconds > 0 ? finalDisplayedWorkoutDurationSeconds : secondsElapsed))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .padding(.vertical, 8)
                    .background(Color.proBackground.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                 

                if !workout.sortedExercises.isEmpty {
                    Text(workout.sortedExercises[currentExerciseIndex].name)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundColor(.red)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Text("Timing general activity...")
                        .font(.system(size: 16, design: .serif))
                        .foregroundColor(.gray)
                        .italic()
                        .padding(.horizontal)
                }

                VStack(spacing: 10) {
                    Button(action: handlePrimaryButtonTap) {
                        Text(primaryButtonText)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityIdentifier(primaryButtonAccessibilityID)

                    if showSecondaryEndButton {
                        Button(action: handleSecondaryEndButtonTap) {
                            Text("End Workout Now")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .accessibilityIdentifier("earlyEndWorkoutButton")
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                if showMetrics && healthKitManager.isAuthorized {
                    VStack(spacing: 4) {
                        if let score = intensityScore {
                            Text("Intensity: \(Int(score))%")
                                .font(.system(size: 14, design: .serif))
                                .foregroundColor(.yellow)
                        }
                        if let score = progressPulseScore {
                            Text("Progress Pulse: \(Int(score))")
                                .font(.system(size: 14, design: .serif))
                                .foregroundColor(.yellow)
                        }
                        if let zone = dominantZone {
                            Text("Zone: \(zone) (\(zoneDescription(zone)))")
                                .font(.system(size: 14, design: .serif))
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.7))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal, 8)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startDate = .now
            secondsElapsed = 0.0
            finalDisplayedWorkoutDurationSeconds = 0.0
            splitTimes = []
            exercisesCompleted = []
            currentExerciseIndex = 0
            startTimer()
            if !workout.sortedExercises.isEmpty {
                debugLog("WorkoutSessionView: Exercises loaded: \(workout.sortedExercises.map { $0.name })")
            } else {
                debugLog("WorkoutSessionView: No exercises in this workout. Will track as general activity.")
            }
            debugLog("WorkoutSessionView: Appeared and reset.")
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            debugLog("WorkoutSessionView: Disappeared, timer invalidated.")
        }
    }

    private var primaryButtonText: String {
        if workout.sortedExercises.isEmpty {
            return "Finish Workout"
        } else if currentExerciseIndex >= workout.sortedExercises.count - 1 {
            return "Complete Workout"
        } else {
            return "Next Exercise"
        }
    }

    private var primaryButtonAccessibilityID: String {
        if workout.sortedExercises.isEmpty {
            return "completeWorkoutButton"
        } else if currentExerciseIndex >= workout.sortedExercises.count - 1 {
            return "completeWorkoutButton"
        } else {
            return "nextExerciseButton"
        }
    }

    private var showSecondaryEndButton: Bool {
        return !workout.sortedExercises.isEmpty && currentExerciseIndex < workout.sortedExercises.count - 1
    }

    private func handlePrimaryButtonTap() {
        if workout.sortedExercises.isEmpty {
            debugLog("WorkoutSessionView: Primary button tapped - Finish Workout (empty workout)")
            completeWorkout()
        } else if currentExerciseIndex >= workout.sortedExercises.count - 1 {
            debugLog("WorkoutSessionView: Primary button tapped - Finish Last Exercise & Workout")
            recordSplitTime()
            if !exercisesCompleted.contains(where: { $0.id == workout.sortedExercises[currentExerciseIndex].id }) {
                exercisesCompleted.append(workout.sortedExercises[currentExerciseIndex])
                debugLog("WorkoutSessionView: Added last exercise to completed: \(workout.sortedExercises[currentExerciseIndex].name)")
            }
            completeWorkout()
        } else {
            debugLog("WorkoutSessionView: Primary button tapped - Next Exercise")
            recordSplitTime()
            exercisesCompleted.append(workout.sortedExercises[currentExerciseIndex])
            currentExerciseIndex += 1
            debugLog("WorkoutSessionView: Advanced to exercise: \(workout.sortedExercises[currentExerciseIndex].name)")
        }
    }

    private func handleSecondaryEndButtonTap() {
        debugLog("WorkoutSessionView: Secondary 'End Workout Now' button tapped.")
        recordSplitTime()
        completeWorkout()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            secondsElapsed += 0.01
        }
    }

    private func formattedTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secondsPart = Int(seconds) % 60
        let milliseconds = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d:%02d.%02d", hours, minutes, secondsPart, milliseconds)
    }

    private func recordSplitTime() {
        guard !workout.sortedExercises.isEmpty, currentExerciseIndex < workout.sortedExercises.count else { return }
        
        let split = SplitTime(
            durationInSeconds: secondsElapsed,
            exercise: workout.sortedExercises[currentExerciseIndex]
        )
        splitTimes.append(split)
        debugLog("WorkoutSessionView: Recorded split time marker for \(workout.sortedExercises[currentExerciseIndex].name) at total elapsed time: \(secondsElapsed)s")
    }

    private func completeWorkout() {
        timer?.invalidate()
        timer = nil
        debugLog("WorkoutSessionView: Timer invalidated immediately on completeWorkout.")

        let finalDurationSeconds: Double
        var exercisesToSave: [Exercise] = []
        var splitsToSave: [SplitTime] = []

        if workout.sortedExercises.isEmpty {
            finalDurationSeconds = self.secondsElapsed
            exercisesToSave = []
            splitsToSave = []
            debugLog("WorkoutSessionView: Completing as simple activity. Total duration: \(finalDurationSeconds)s")
        } else {
            if currentExerciseIndex < workout.sortedExercises.count && !exercisesCompleted.contains(where: { $0.id == workout.sortedExercises[currentExerciseIndex].id }) {
                 exercisesCompleted.append(workout.sortedExercises[currentExerciseIndex])
                 debugLog("WorkoutSessionView: Added final/current exercise to completed list: \(workout.sortedExercises[currentExerciseIndex].name)")
            }
            finalDurationSeconds = self.secondsElapsed
            exercisesToSave = self.exercisesCompleted
            splitsToSave = self.splitTimes
            debugLog("WorkoutSessionView: Completing structured workout. Total duration: \(finalDurationSeconds)s. Exercises completed: \(exercisesToSave.map{$0.name})")
        }
        
        let totalDurationInMinutes = finalDurationSeconds / 60.0
        self.finalDisplayedWorkoutDurationSeconds = finalDurationSeconds
        
        let workoutEndDate = startDate.addingTimeInterval(finalDurationSeconds)

        let history = History(
            date: startDate,
            exercisesCompleted: exercisesToSave,
            splitTimes: splitsToSave,
            lastSessionDuration: totalDurationInMinutes
        )
        workout.dateCompleted = .now
        workout.lastSessionDuration = totalDurationInMinutes

        Task {
            var historyToSave = history
            var shouldShowMetrics = false
            
            self.collectedHKSamples = []

            if healthKitManager.isAuthorized {
                debugLog("WorkoutSessionView: User unlocked and HK authorized. Attempting metric calculation and HK save.")
                do {
                    let hrSamples = await fetchHeartRateSamples(from: startDate, to: workoutEndDate)
                    self.collectedHKSamples.append(contentsOf: hrSamples)
                    debugLog("WorkoutSessionView: Fetched \(hrSamples.count) heart rate samples.")

                    if let activeEnergySample = createActiveEnergySample(durationInSeconds: finalDurationSeconds, workoutStartDate: startDate, workoutEndDate: workoutEndDate) {
                        self.collectedHKSamples.append(activeEnergySample)
                        debugLog("WorkoutSessionView: Added estimated active energy sample to collected samples.")
                    } else {
                        debugLog("WorkoutSessionView: Could not create active energy sample (missing weight or category).")
                    }

                    historyToSave = await calculateAdvancedMetrics(history: history)
                    shouldShowMetrics = true

                    let success = try await healthKitManager.saveWorkout(workout, history: historyToSave, samples: self.collectedHKSamples)
                    if success {
                        debugLog("WorkoutSessionView: Workout saved successfully to HealthKit.")
                    } else {
                        debugLog("WorkoutSessionView: HealthKit saveWorkout returned false.")
                        throw HealthKitError.workoutSaveFailed("HealthKitManager reported save failure.")
                    }
                } catch {
                    debugLog("WorkoutSessionView: Error during metric calculation, sample fetching, or HealthKit save: \(error.localizedDescription)")
                    await MainActor.run {
                        if case .appPurchaseRequired = error as? HealthKitError {
                            errorManager.presentAlert(
                                title: "Purchase Required",
                                message: "Please purchase the app to save workouts to HealthKit."
                            )
                        } else {
                            errorManager.presentAlert(
                                title: "HealthKit/Metric Save Failed",
                                message: "Could not save to HealthKit, fetch samples, or calculate metrics: \(error.localizedDescription)"
                            )
                        }
                    }
                    shouldShowMetrics = false
                }
            } else {
                debugLog("WorkoutSessionView: User not unlocked or HK not authorized. Skipping metrics, sample fetching, and HK save.")
            }

            workout.history.append(historyToSave)
            workout.updatePersonalBest()
            debugLog("WorkoutSessionView: Called updatePersonalBest() after appending new history.")
            
            workout.updateAISummary(context: modelContext)

            do {
                try modelContext.save()
                debugLog("WorkoutSessionView: Workout saved to SwiftData (History with metrics: \(historyToSave.intensityScore != nil || historyToSave.progressPulseScore != nil || historyToSave.dominantZone != nil)).")
                NotificationCenter.default.post(name: .workoutDidComplete, object: nil)
                debugLog("WorkoutSessionView: Posted .workoutDidComplete notification.")
                await MainActor.run {
                    if shouldShowMetrics {
                        self.intensityScore = historyToSave.intensityScore
                        self.progressPulseScore = historyToSave.progressPulseScore
                        self.dominantZone = historyToSave.dominantZone
                        self.showMetrics = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            dismiss()
                        }
                    } else {
                        dismiss()
                    }
                }
            } catch {
                debugLog("WorkoutSessionView: CRITICAL - SwiftData Save error: \(error.localizedDescription)")
                await MainActor.run {
                    errorManager.presentAlert(
                        title: "Workout Save Failed",
                        message: "Failed to save workout session locally: \(error.localizedDescription)"
                    )
                }
            }
        }
    }

    private func fetchHeartRateSamples(from workoutStartDate: Date, to workoutEndDate: Date) async -> [HKQuantitySample] {
        guard healthKitManager.isAuthorized else {
            debugLog("fetchHeartRateSamples: HealthKit not authorized. Cannot fetch samples.")
            return []
        }

        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            debugLog("fetchHeartRateSamples: Heart rate type is not available.")
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: workoutStartDate, end: workoutEndDate, options: .strictStartDate)
        
        let realSamples: [HKQuantitySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    self.debugLog("fetchHeartRateSamples: Error fetching real heart rate samples - \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }
                guard let heartRateSamples = samples as? [HKQuantitySample] else {
                    self.debugLog("fetchHeartRateSamples: No real heart rate samples found or samples are not HKQuantitySample.")
                    continuation.resume(returning: [])
                    return
                }
                self.debugLog("fetchHeartRateSamples: Successfully fetched \(heartRateSamples.count) real heart rate samples.")
                continuation.resume(returning: heartRateSamples)
            }
            HKHealthStore().execute(query)
        }

        #if DEBUG
        if realSamples.isEmpty
        {
            debugLog("fetchHeartRateSamples: DEBUG mode - No real samples found or dummy data forced. Generating dummy heart rate samples.")
            var dummySamples: [HKQuantitySample] = []
            let sampleCount = 5
            let duration = workoutEndDate.timeIntervalSince(workoutStartDate)
            
            guard duration > 0 else {
                 debugLog("fetchHeartRateSamples: DEBUG mode - Workout duration is zero or negative, cannot generate dummy samples.")
                return []
            }

            for i in 0..<sampleCount {
                let sampleTime = workoutStartDate.addingTimeInterval((duration / Double(sampleCount)) * Double(i))
                let heartRateValue = Double.random(in: 90...150)
                let heartRateQuantity = HKQuantity(unit: HKUnit(from: "count/min"), doubleValue: heartRateValue)
                let dummySample = HKQuantitySample(type: heartRateType, quantity: heartRateQuantity, start: sampleTime, end: sampleTime)
                dummySamples.append(dummySample)
            }
            debugLog("fetchHeartRateSamples: DEBUG mode - Generated \(dummySamples.count) dummy heart rate samples.")
            return dummySamples
        }
        #endif

        return realSamples
    }

    private func createActiveEnergySample(durationInSeconds: Double, workoutStartDate: Date, workoutEndDate: Date) -> HKQuantitySample? {
        guard let userWeightKg = authManager.currentAppleUser?.weight, userWeightKg > 0 else {
            debugLog("createActiveEnergySample: User weight not available or invalid from authManager.currentAppleUser (Weight: \(String(describing: authManager.currentAppleUser?.weight))). Cannot create active energy sample.")
            return nil
        }

        guard let category = workout.category else {
            debugLog("createActiveEnergySample: Workout category not available. Cannot create active energy sample.")
            return nil
        }
        
        let metValue = category.categoryColor.metValue
        debugLog("createActiveEnergySample: Using MET value: \(metValue) for category: \(category.categoryName)")

        guard durationInSeconds > 0 else {
            debugLog("createActiveEnergySample: Workout duration is zero or negative (\(durationInSeconds)s). Cannot create active energy sample.")
            return nil
        }

        let durationInMinutes = durationInSeconds / 60.0

        let caloriesBurned = (metValue * 3.5 * userWeightKg) / 200.0 * durationInMinutes
        
        debugLog("createActiveEnergySample: Calculation: MET(\(metValue)) * 3.5 * Weight(\(userWeightKg)kg) / 200.0 * Duration(\(durationInMinutes)min) = \(caloriesBurned) kcal.")

        guard caloriesBurned > 0 else {
            debugLog("createActiveEnergySample: Calculated calories burned is zero or negative (\(caloriesBurned) kcal). Not creating sample.")
            return nil
        }

        guard let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            debugLog("createActiveEnergySample: Active energy type (HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)) is not available. Cannot create sample.")
            return nil
        }

        let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: caloriesBurned)
        
        let energySample = HKQuantitySample(
            type: activeEnergyType,
            quantity: energyQuantity,
            start: workoutStartDate,
            end: workoutEndDate
        )
        debugLog("createActiveEnergySample: Successfully created HKQuantitySample for active energy: \(energyQuantity).")
        return energySample
    }

    private func calculateAdvancedMetrics(history: History) async -> History {
        let dateInterval = DateInterval(
            start: history.date,
            end: history.date.addingTimeInterval(history.lastSessionDuration * 60)
        )

        let restingHR = await fetchLatestRestingHeartRateAsync()
        history.intensityScore = await calculateIntensityScoreAsync(dateInterval: dateInterval, restingHeartRate: restingHR)
        debugLog("Intensity Score calculated: \(String(describing: history.intensityScore))")

        let maxHR = fetchUserMaxHeartRate() ?? Double(220 - (fetchUserAge() ?? 30))
        let (_, calculatedDominantZone) = await calculateTimeInZonesAsync(dateInterval: dateInterval, maxHeartRate: maxHR)
        history.dominantZone = calculatedDominantZone
        debugLog("Dominant Zone calculated: \(String(describing: history.dominantZone))")
        
        let workoutsPerWeek = fetchWorkoutsPerWeek()
        history.progressPulseScore = healthKitManager.calculateProgressPulseScore(
            personalBest: workout.personalBest ?? history.lastSessionDuration,
            currentDuration: history.lastSessionDuration,
            workoutsPerWeek: workoutsPerWeek,
            targetWorkoutsPerWeek: 3,
            dominantZone: history.dominantZone
        )
        debugLog("Progress Pulse calculated: \(String(describing: history.progressPulseScore))")

        return history
    }

    private func fetchLatestRestingHeartRateAsync() async -> Double? {
        await withCheckedContinuation { continuation in
            healthKitManager.fetchLatestRestingHeartRate { restingHR, error in
                if let error {
                    debugLog("fetchLatestRestingHeartRateAsync: Error - \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: restingHR)
                }
            }
        }
    }

    private func calculateIntensityScoreAsync(dateInterval: DateInterval, restingHeartRate: Double?) async -> Double? {
        await withCheckedContinuation { continuation in
            healthKitManager.calculateIntensityScore(dateInterval: dateInterval, restingHeartRate: restingHeartRate) { intensityScore, error in
                if let error {
                    debugLog("calculateIntensityScoreAsync: Error - \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: intensityScore)
                }
            }
        }
    }

    private func calculateTimeInZonesAsync(dateInterval: DateInterval, maxHeartRate: Double?) async -> ([Int: Double]?, Int?) {
        await withCheckedContinuation { continuation in
            healthKitManager.calculateTimeInZones(dateInterval: dateInterval, maxHeartRate: maxHeartRate) { timeInZones, dominantZone, error in
                if let error {
                    debugLog("calculateTimeInZonesAsync: Error - \(error.localizedDescription)")
                    continuation.resume(returning: (nil, nil))
                } else {
                    continuation.resume(returning: (timeInZones, dominantZone))
                }
            }
        }
    }

    private func fetchUserMaxHeartRate() -> Double? {
        guard let currentUserId = authManager.currentAppleUser?.appleUserId else {
            debugLog("fetchUserMaxHeartRate: No current user ID available.")
            return nil
        }
        let predicate = #Predicate<User> { $0.appleUserId == currentUserId }
        var descriptor = FetchDescriptor<User>(predicate: predicate)
        descriptor.propertiesToFetch = [\.maxHeartRate]
        do {
            if let user = try modelContext.fetch(descriptor).first {
                return user.maxHeartRate
            }
        } catch {
            debugLog("fetchUserMaxHeartRate: Error fetching user - \(error.localizedDescription)")
        }
        debugLog("fetchUserMaxHeartRate: User not found or maxHeartRate is nil.")
        return nil
    }

    private func fetchUserAge() -> Int? {
        guard let currentUserId = authManager.currentAppleUser?.appleUserId else {
            debugLog("fetchUserAge: No current user ID available.")
            return nil
        }
        let predicate = #Predicate<User> { $0.appleUserId == currentUserId }
        var descriptor = FetchDescriptor<User>(predicate: predicate)
        descriptor.propertiesToFetch = [\.age]
        do {
            if let user = try modelContext.fetch(descriptor).first {
                return user.age
            }
        } catch {
            debugLog("fetchUserAge: Error fetching user - \(error.localizedDescription)")
        }
        debugLog("fetchUserAge: User not found or age is nil.")
        return nil
    }

    private func fetchWorkoutsPerWeek() -> Int {
        guard let startOfWeek = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)) else {
            debugLog("fetchWorkoutsPerWeek: Could not determine start of week.")
            return 0
        }
        let now = Date()
        let targetWorkoutID = workout.persistentModelID

        let predicate = #Predicate<History> { history in
            history.date >= startOfWeek && history.date <= now && history.workout?.persistentModelID == targetWorkoutID
        }
        let descriptor = FetchDescriptor<History>(predicate: predicate)
        do {
            let count = try modelContext.fetchCount(descriptor)
            debugLog("fetchWorkoutsPerWeek: Found \(count) workouts this week for workout ID \(targetWorkoutID).")
            return count
        } catch {
            debugLog("fetchWorkoutsPerWeek: Error fetching count - \(error.localizedDescription)")
            return 0
        }
    }

    private func zoneDescription(_ zone: Int) -> String {
        switch zone {
        case 1: return "Very Light"
        case 2: return "Light"
        case 3: return "Moderate"
        case 4: return "Hard"
        case 5: return "Maximum"
        default: return "Unknown"
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[WorkoutSessionView] \(message)")
        #endif
    }
}
