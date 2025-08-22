import SwiftUI
import UserNotifications
import SwiftData

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    @AppStorage("notificationsEnabled") private var globalNotificationsEnabled: Bool = true

    private init() {}

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Notification authorization error: \(error.localizedDescription)")
                }
                if !granted {
                     print("Notification permission was denied.")
                }
                completion(granted)
            }
        }
    }

    func scheduleOrUpdateNotification(for workout: MoveMD1_0.Workout) {
        guard globalNotificationsEnabled else {
            // Accessing properties like workout.title will now refer to MoveMD1_0.Workout.title
            print("Global notifications are disabled. Skipping scheduling for workout: \(workout.title)")
            cancelNotification(for: workout)
            return
        }

        guard let scheduleDate = workout.scheduleDate, scheduleDate > Date() else {
            print("Workout '\(workout.title)' has no schedule date or is in the past. Cancelling any existing notification.")
            cancelNotification(for: workout)
            return
        }
        
        // Ensure we have permission before trying to schedule
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                print("Notification permission not granted. Cannot schedule for workout: \(workout.title)")
                return
            }

            // Proceed to schedule on the main thread if UI updates are involved or for consistency
            DispatchQueue.main.async {
                self._scheduleNotification(workout: workout, scheduleDate: scheduleDate)
            }
        }
    }
    
    private func _scheduleNotification(workout: MoveMD1_0.Workout, scheduleDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Workout Reminder"
        content.body = "Time for your scheduled workout: \(workout.title)!"
        content.sound = .default
        // Assuming persistentModelID is a property of the SwiftData generated class for MoveMD1_0.Workout
        content.userInfo = ["workoutID": workout.persistentModelID.storeIdentifier?.description ?? ""]

        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: scheduleDate)

        let repeats: Bool
        switch workout.repeatOption ?? .none { // .none here will infer Workout.RepeatOption.none
            case .none:
                repeats = false
            case .daily:
                // For daily, we only need hour and minute for repetition
                dateComponents = calendar.dateComponents([.hour, .minute], from: scheduleDate)
                repeats = true
            case .weekly:
                // For weekly, we need weekday, hour, and minute
                dateComponents = calendar.dateComponents([.weekday, .hour, .minute], from: scheduleDate)
                repeats = true
            case .monthly:
                // For monthly, repeat on the same day, hour, and minute
                dateComponents = calendar.dateComponents([.day, .hour, .minute], from: scheduleDate)
                repeats = true
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeats)
        let requestIdentifier = "workout-\(workout.persistentModelID.storeIdentifier?.description ?? workout.title)" // Unique ID based on workout
        
        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification for workout '\(workout.title)': \(error.localizedDescription)")
            } else {
                print("Successfully scheduled notification for workout '\(workout.title)' at \(scheduleDate) with repeat: \(workout.repeatOption?.rawValue ?? "none"). ID: \(requestIdentifier)")
                if repeats {
                    print("Repeating components: \(dateComponents)")
                }
            }
        }
    }

    func cancelNotification(for workout: MoveMD1_0.Workout) {
        let requestIdentifier = "workout-\(workout.persistentModelID.storeIdentifier?.description ?? workout.title)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
        print("Cancelled notification for workout '\(workout.title)'. ID: \(requestIdentifier)")
    }

    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("All pending workout notifications cancelled.")
    }
    
    // This function could be called at app startup or when user toggles notifications in settings
    @MainActor
    func checkAndRescheduleAllNotifications(modelContext: ModelContext) {
        guard globalNotificationsEnabled else {
            cancelAllNotifications()
            return
        }
        
        let now = Date()
        let predicate = #Predicate<MoveMD1_0.Workout> { workout in
            workout.scheduleDate != nil
        }

        let descriptor = FetchDescriptor<MoveMD1_0.Workout>(predicate: predicate)
        
        do {
            let allScheduledWorkouts = try modelContext.fetch(descriptor)
            
            // Filter in Swift for workouts that are actually in the future.
            let futureScheduledWorkouts = allScheduledWorkouts.filter { workout in
                // We can safely force-unwrap scheduleDate here because the predicate
                // already ensured it's not nil.
                return workout.scheduleDate! > now
            }
            
            print("Found \(futureScheduledWorkouts.count) workouts with future schedule dates to potentially reschedule.")
            for workout in futureScheduledWorkouts {
                scheduleOrUpdateNotification(for: workout)
            }
        } catch {
            print("Error fetching workouts for rescheduling notifications: \(error)")
        }
    }
}
