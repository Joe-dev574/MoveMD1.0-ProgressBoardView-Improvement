//
//  WorkoutDetailView.swift
//  MoveMD1.0
//
//  Created by Joseph DeWeese on 4/29/25.
//

import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    let workout: Workout
    @EnvironmentObject var errorManager: ErrorManager
    
    private static let scheduleDateFormatterStatic: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    private func zoneDescription(for zone: Int?) -> String? {
        guard let zone = zone else { return nil }
        switch zone {
        case 1: return "Very Light"
        case 2: return "Light"
        case 3: return "Moderate"
        case 4: return "Hard"
        case 5: return "Maximum"
        default: return "Unknown"
        }
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
                    beginWorkoutSection
                    categorySection
                    exercisesSection
                    timeMetricsSection
                    scheduleSection
                    aiSummarySection
                    historySection
                }
                .scrollContentBackground(.hidden)
                .navigationTitle("Workout Review")
                .navigationBarTitleDisplayMode(.inline)
                .tint(workout.category?.categoryColor.color ?? .blue)
                .toolbar {
                    NavigationLink {
                        WorkoutEditView(workout: workout)
                    } label: {
                        Text("Edit")
                            .font(.system(.body, design: .serif).weight(.medium))
                            .padding(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                            .background((workout.category?.categoryColor.color ?? Color.accentColor).opacity(0.15))
                            .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    private var beginWorkoutSection: some View {
        Section {
            NavigationLink {
                WorkoutSessionView(workout: workout)
            } label: {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Begin Workout")
                }
                .font(.headline)
                .fontDesign(.serif)
                .foregroundStyle(.blue)
            }
            .accessibilityIdentifier("beginWorkoutLink")
            .accessibilityLabel("Begin workout")
            .accessibilityHint("Start the workout session")
        }
    }
    
    private var categorySection: some View {
        Section {
            if let category = workout.category {
                HStack {
                    Image(systemName: category.symbol)
                        .foregroundStyle(workout.category?.categoryColor.color ?? .secondary)
                        .font(.system(size: 16))
                    Text(category.categoryName)
                        .foregroundStyle(.primary)
                        .font(.system(size: 16))
                        .fontDesign(.serif)
                }
            } else {
                Text("No category selected")
                    .fontDesign(.serif)
                    .italic()
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Workout Category")
                .font(.system(size: 18, design: .serif))
                .fontWeight(.semibold)
                .foregroundStyle(workout.category?.categoryColor.color ?? .secondary)
        }
    }
    
    private var exercisesSection: some View {
        Section {
            if workout.sortedExercises.isEmpty {
                Text("No exercises added yet.")
                    .fontDesign(.serif)
                    .italic()
                    .foregroundStyle(.secondary)
            } else {
                ForEach(workout.sortedExercises.indices, id: \.self) { index in
                    HStack(spacing: 10) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundStyle(workout.category?.categoryColor.color ?? .secondary)
                        Text(workout.sortedExercises[index].name)
                            .foregroundStyle(.primary)
                    }
                    .font(.system(size: 16))
                    .fontDesign(.serif)
                }
            }
        } header: {
            Text("Exercises")
                .font(.system(size: 18, design: .serif))
                .fontWeight(.semibold)
                .foregroundStyle(workout.category?.categoryColor.color ?? .secondary)
        }
    }
    
    private var timeMetricsSection: some View {
        Section {
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(workout.category?.categoryColor.color ?? .secondary)
                Text("Last Session:")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(TimeFormatter.formatDuration(workout.lastSessionDuration * 60))
                    .foregroundStyle(.primary)
            }
            .fontDesign(.serif)
            .font(.system(size: 16))
            
            if let personalBest = workout.personalBest, personalBest > 0 {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("Personal Best:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(TimeFormatter.formatDuration(personalBest * 60))
                        .foregroundStyle(.primary)
                }
                .fontDesign(.serif)
                .font(.system(size: 16))
            } else {
                HStack {
                    Image(systemName: "star")
                        .foregroundStyle(.gray)
                    Text("No personal best yet")
                        .fontDesign(.serif)
                        .italic()
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Time Metrics")
                .font(.system(size: 18, design: .serif))
                .fontWeight(.semibold)
                .foregroundStyle(workout.category?.categoryColor.color ?? .secondary)
        }
    }
    
    private var scheduleSection: some View {
        Section(header: Text("Schedule")
                    .font(.system(size: 18, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundStyle(workout.category?.categoryColor.color ?? .secondary)
        ) {
            if let scheduleDate = workout.scheduleDate {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(workout.category?.categoryColor.color ?? .secondary)
                    Text("Scheduled:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Self.scheduleDateFormatterStatic.string(from: scheduleDate))
                        .foregroundStyle(.primary)
                }
            } else {
                HStack {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundStyle(.gray)
                    Text("Not scheduled")
                        .fontDesign(.serif)
                        .italic()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var aiSummarySection: some View {
        Section {
            if let summary = workout.aiGeneratedSummary, !summary.isEmpty {
                Text(summary)
                    .font(.body)
                    .foregroundStyle(.primary)
            } else {
                Text("Complete the workout to generate an AI summary.")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("AI Workout Summary")
                .font(.system(size: 18, design: .serif))
                .fontWeight(.semibold)
                .foregroundStyle(workout.category?.categoryColor.color ?? .gray)
        }
    }
    
    private var historySection: some View {
        Section(header: Text("Recent History")
                    .font(.system(size: 18, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundStyle(workout.category?.categoryColor.color ?? .gray)
        ) {
            historySectionContent
        }
    }

    @ViewBuilder
    private var historySectionContent: some View {
        if workout.history.isEmpty {
            Text("No completed sessions yet.")
                .foregroundStyle(.secondary)
                .fontDesign(.serif)
                .italic()
        } else {
            ForEach(workout.history.sorted(by: { $0.date > $1.date }).prefix(3)) { historyItem in
                VStack(alignment: .leading, spacing: 8) { 
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(workout.category?.categoryColor.color ?? .secondary)
                            .font(.system(size: 16))
                        VStack(alignment: .leading) {
                            Text(historyItem.date, style: .date)
                            Text("Duration: \(TimeFormatter.formatDuration(historyItem.lastSessionDuration * 60))")
                                .font(.caption)
                                .fontDesign(.serif)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) { 
                        if let intensity = historyItem.intensityScore {
                            Text("Intensity: \(String(format: "%.0f", intensity))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let pulse = historyItem.progressPulseScore {
                            Text("Pulse Score: \(String(format: "%.0f", pulse))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let zone = historyItem.dominantZone, let description = zoneDescription(for: zone) {
                            Text("Dominant Zone: \(zone) (\(description))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 28) 
                    
                }
                .contentShape(Rectangle()) 
                .background(NavigationLink("", destination: HistoryView(workout: workout)).opacity(0)) 
                .accessibilityElement(children: .combine)
                .accessibilityHint("View full workout history")
            }
            if workout.history.count > 3 {
                NavigationLink("View All History") {
                    HistoryView(workout: workout)
                }
                .foregroundStyle(.blue)
                .font(.subheadline)
            }
        }
    }
}

#if DEBUG
private struct WorkoutDetailPreviewWrapper: View {
    @State private var container: ModelContainer?
    @State private var workout: Workout?
    @State private var error: Error?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading Preview...")
            } else if let error = error {
                Text("Failed to create preview: \(error.localizedDescription)")
                    .padding()
            } else if let container = container, let workout = workout {
                NavigationStack {
                    WorkoutDetailView(workout: workout)
                        .modelContainer(container)
                        .environmentObject(PurchaseManager.shared)
                }
            } else {
                Text("Preview unavailable.")
            }
        }
        .task {
            guard isLoading else { return }
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                let localContainer = try ModelContainer(for: Workout.self, History.self, Category.self, Exercise.self, User.self, SplitTime.self, configurations: config) // Ensure all models are registered if needed for preview relationships

                let sampleWorkout = Workout(title: "Sample Chest Day", dateCreated: .now)
                sampleWorkout.scheduleDate = Calendar.current.date(byAdding: .day, value: 1, to: .now)
                
                let history1 = History(
                    date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!,
                    exercisesCompleted: [], // Added to satisfy History initializer
                    splitTimes: [], // Added to satisfy History initializer
                    lastSessionDuration: 15.0,
                    intensityScore: 75,
                    progressPulseScore: 80,
                    dominantZone: 3
                )
                let history2 = History(
                    date: Calendar.current.date(byAdding: .day, value: -3, to: .now)!,
                    exercisesCompleted: [], // Added to satisfy History initializer
                    splitTimes: [], // Added to satisfy History initializer
                    lastSessionDuration: 18.0,
                    intensityScore: 60, // Add some metrics here too
                    progressPulseScore: 70,
                    dominantZone: 2
                )
                let history3 = History(
                    date: Calendar.current.date(byAdding: .day, value: -5, to: .now)!,
                    exercisesCompleted: [],
                    splitTimes: [],
                    lastSessionDuration: 22.0
                )


                sampleWorkout.history.append(history1)
                sampleWorkout.history.append(history2)
                sampleWorkout.history.append(history3) // Add third history item
                localContainer.mainContext.insert(sampleWorkout)
                // Ensure history items are also inserted if not automatically cascaded by relationship (SwiftData usually handles this)
                localContainer.mainContext.insert(history1)
                localContainer.mainContext.insert(history2)
                localContainer.mainContext.insert(history3)


                self.container = localContainer
                self.workout = sampleWorkout
                self.error = nil
            } catch let setupError {
                self.error = setupError
                self.container = nil
                self.workout = nil
            }
            self.isLoading = false
        }
    }
}

struct WorkoutDetailView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutDetailPreviewWrapper()
    }
}
#endif
