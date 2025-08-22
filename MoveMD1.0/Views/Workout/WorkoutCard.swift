import SwiftUI
import SwiftData

struct WorkoutCard: View {
    let workout: Workout
    private var exerciseCount: Int { workout.exercises.count }
    private var formattedDate: String {
        workout.dateCreated.formatted(date: .long, time: .omitted)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            workoutTitle
            exerciseInfo
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
    
    private var workoutTitle: some View {
        HStack {
            Circle()
                .fill(workout.category?.categoryColor.color ?? .gray)
                .frame(width: 35, height: 35)
                .overlay {
                    Image(systemName: workout.category?.symbol ?? "figure.highintensity.intervaltraining")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                }
            
            Text(workout.title)
                .font(.headline)
                .fontDesign(.serif)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            
            Spacer()
        }
    }
    
    private var exerciseInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("\(exerciseCount) \(exerciseCount == 1 ? "Exercise" : "Exercises")")
            } icon: {
                Image(systemName: "arrow.forward.circle")
            }
            .font(.caption)
            .foregroundStyle(.primary)
            
            Group {
                Label("Previous Workout Time: \(lastSessionTime)", systemImage: "hourglass.bottomhalf.filled")
                Label("Personal Record Time: \(personalBestTime)", systemImage: "stopwatch")
                Label("Created: \(formattedDate)", systemImage: "calendar")
            }
            .font(.caption)
            .fontDesign(.serif)
            .foregroundStyle(.primary)
        }
    }
    
    private var lastSessionTime: String {
        if workout.lastSessionDuration > 0 {
            return formatTime(minutes: workout.lastSessionDuration)
        } else {
            return "N/A"
        }
    }
    
    private var personalBestTime: String {
        if let personalBest = workout.personalBest, personalBest > 0 {
            return formatTime(minutes: personalBest)
        } else {
            return "N/A"
        }
    }
    
    private func formatTime(minutes: Double) -> String {
        let totalSeconds = minutes * 60
        let intSeconds = Int(totalSeconds)
        let fractionalSeconds = totalSeconds - Double(intSeconds)
        let milliseconds = Int(fractionalSeconds * 1000)
        let hours = intSeconds / 3600
        let minutesPart = (intSeconds % 3600) / 60
        let secondsPart = intSeconds % 60
        return String(format: "%02d:%02d:%02d.%02d", hours, minutesPart, secondsPart, milliseconds)
    }
}
