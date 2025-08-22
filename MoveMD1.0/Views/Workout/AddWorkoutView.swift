//
//  AddWorkoutView.swift
//  MoveMD1.0
//
//  Created by Joseph DeWeese on 4/29/25.
//

import SwiftUI
import SwiftData

struct AddWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var errorManager: ErrorManager

    let workout: Workout? // This can likely be removed if AddWorkoutView is only for new workouts
    
    @State private var title: String
    @State private var exercises: [Exercise]
    @State private var lastSessionDuration: Double // This might be irrelevant for a new workout template
    @State private var dateCreated: Date
    @State private var selectedCategory: Category?
    @State private var scheduleDate: Date?
    @State private var repeatOption: Workout.RepeatOption = .none // Default to .none

    @State private var showCategoryPicker: Bool = false
    
    init(workout: Workout? = nil) { // If workout param is only for editing, consider renaming this view or having separate views.
                                     // For now, assuming it could pre-fill from a template if workout was passed.
        self.workout = workout
        if let workout = workout { // This block suggests it might be used for editing or pre-filling
            _title = .init(initialValue: workout.title)
            _exercises = .init(initialValue: workout.exercises)
            _lastSessionDuration = .init(initialValue: workout.lastSessionDuration)
            _dateCreated = .init(initialValue: workout.dateCreated)
            _selectedCategory = .init(initialValue: workout.category)
            _scheduleDate = .init(initialValue: workout.scheduleDate)
            _repeatOption = .init(initialValue: workout.repeatOption ?? .none)
        } else { // This is the typical "Add New" path
            _title = State(initialValue: "")
            _exercises = State(initialValue: [])
            _lastSessionDuration = State(initialValue: 0) // Typically 0 for a new workout template
            _dateCreated = State(initialValue: Date())
            _selectedCategory = State(initialValue: nil)
            _scheduleDate = State(initialValue: nil)
            _repeatOption = State(initialValue: .none)
        }
    }
    
    var body: some View {
        ZStack {
            backgroundView
            contentView
        }
    }
    
    private var backgroundView: some View {
        LinearGradient(
            gradient: Gradient(colors: [.gray.opacity(0.02), .gray.opacity(0.1)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var contentView: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name of Workout...", text: $title)
                        .font(.system(.body, design: .serif))
                        .textInputAutocapitalization(.words)
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("workoutTitleField")
                } header: {
                    Text("Title")
                        .font(.system(size: 18, design: .serif))
                        .fontWeight(.semibold)
                        .foregroundStyle(selectedCategory?.categoryColor.color ?? .primary)
                }
                
                Section {
                    Button(action: {
                        showCategoryPicker = true
                    }) {
                        HStack {
                            if let category = selectedCategory {
                                Image(systemName: category.symbol)
                                    .foregroundColor(category.categoryColor.color)
                                    .font(.title3)
                                Text(category.categoryName)
                                    .foregroundStyle(.primary)
                            } else {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                                Text("Select Category")
                                    .foregroundStyle(.primary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .font(.system(.body, design: .serif))
                    }.accessibilityIdentifier("categoryButton")
                } header: {
                    Text("Workout Category")
                        .font(.system(size: 18, design: .serif))
                        .fontWeight(.semibold)
                        .foregroundStyle(selectedCategory?.categoryColor.color ?? .primary)
                }

                Section(header: Text("Schedule Workout").font(.system(size: 18, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundStyle(selectedCategory?.categoryColor.color ?? .primary)
                ) {
                    Toggle(isOn: Binding(
                        get: { scheduleDate != nil },
                        set: { isOn in
                            if isOn {
                                if scheduleDate == nil { // Only set to default if it's currently nil
                                    scheduleDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
                                }
                            } else {
                                scheduleDate = nil
                                repeatOption = .none // Reset repeat option when scheduling is turned off
                            }
                        }
                    )) {
                        Text("Enable Scheduling")
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(.primary)
                    }

                    if scheduleDate != nil {
                        DatePicker(
                            "Workout Date & Time",
                            selection: Binding<Date>( // Explicitly create Binding<Date>
                                get: { scheduleDate ?? Date() }, // Provide a default if scheduleDate is nil
                                set: { scheduleDate = $0 }      // Set the scheduleDate
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("scheduleDatePicker")

                        Picker("Repeat", selection: $repeatOption) { // Direct binding to non-optional
                            ForEach(Workout.RepeatOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("repeatOptionPicker")
                    }
                }
                
                Section {
                    ForEach($exercises) { $exercise in
                        TextField("Exercise (e.g., Push-ups 10x10)", text: $exercise.name)
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(.primary)
                    }
                    .onDelete { offsets in
                        exercises.remove(atOffsets: offsets)
                        updateExerciseOrders()
                    }
                    Button(action: {
                        exercises.append(Exercise(name: "", order: exercises.count))
                    }) {
                        Text("Add Exercise")
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(.blue)
                    }
                } header: {
                    Text("Exercises")
                        .font(.system(size: 18, design: .serif))
                        .fontWeight(.semibold)
                        .foregroundStyle(selectedCategory?.categoryColor.color ?? .primary)
                }
            }
            .navigationTitle(workout == nil ? "Add Workout" : "Edit Workout") // Adjust title
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .foregroundStyle(.primary)
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPicker(selectedCategory: $selectedCategory)
            }
        }
    }
    
    private var toolbarItems: some ToolbarContent {
        Group {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(.primary) // Changed to primary for better theme adaptability
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    save()
                    print("save button pressed")
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(.white) // Keep prominent for save
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private func updateExerciseOrders() {
        for (index, exercise) in exercises.enumerated() {
            exercise.order = index
        }
    }
    
    private func save() {
        updateExerciseOrders() // Ensure order is set before filtering
        
        // If 'workout' is not nil, we are editing. Otherwise, creating new.
        // This logic needs to be clear. For now, assuming this view primarily adds new.
        // If it's truly for ADDING, then `self.workout` might always be nil or unused for update.

        let newWorkout = Workout( // Always create a new workout instance for "Add"
            title: title,
            exercises: exercises.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            lastSessionDuration: lastSessionDuration, // For a new workout, this is likely 0 or not set by user here.
            dateCreated: dateCreated,
            category: selectedCategory,
            scheduleDate: scheduleDate,
            repeatOption: scheduleDate == nil ? .none : repeatOption // if no schedule date, no repeat
        )
        context.insert(newWorkout)
        
        do {
            try context.save()
            print("Workout saved: \(newWorkout.title)")

            Task {
                await MainActor.run {
                    NotificationManager.shared.scheduleOrUpdateNotification(for: newWorkout)
                }
            }
            dismiss()
        } catch {
            errorManager.presentAlert(
                title: "Failed to Save Workout",
                message: "We couldn't save your workout. Error: \(error.localizedDescription)"
            )
            print("Save error: \(error.localizedDescription)")
        }
    }
}
