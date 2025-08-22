//
//  WorkoutEditView.swift
//  MoveMD1.0
//
//  Created by Grok on 5/7/25.
//

import SwiftUI
import SwiftData

struct WorkoutEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var errorManager: ErrorManager
    let workout: Workout
    @State private var title: String
    @State private var sortedExercises: [Exercise]
    @State private var selectedCategory: Category?
    @State private var scheduleDate: Date?
    @State private var repeatOption: Workout.RepeatOption? 
    @State private var showCategoryPicker: Bool = false
    
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    
    init(workout: Workout) {
        self.workout = workout
        _title = State(initialValue: workout.title)
        _sortedExercises = State(initialValue: workout.sortedExercises)
        _selectedCategory = State(initialValue: workout.category)
        _scheduleDate = State(initialValue: workout.scheduleDate)
        _repeatOption = State(initialValue: workout.repeatOption ?? Workout.RepeatOption.none)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Title").font(.system(size: 18, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundStyle(selectedCategory?.categoryColor.color ?? .secondary)) {
                    TextField("Name of Workout...", text: $title)
                        .font(.system(.body, design: .serif))
                        .textInputAutocapitalization(.words)
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("workoutTitleField")
                }
                
                Section(header: Text("Workout Category").font(.system(size: 18, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundStyle(selectedCategory?.categoryColor.color ?? .secondary)) {
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
                    }
                    .accessibilityIdentifier("categoryButton")
                }

                Section(header: Text("Schedule Workout").font(.system(size: 18, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundStyle(selectedCategory?.categoryColor.color ?? .secondary)) {
                    
                    Toggle(isOn: Binding(
                        get: { scheduleDate != nil },
                        set: { isOn in
                            if isOn {
                                if scheduleDate == nil {
                                    scheduleDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date() 
                                }
                            } else {
                                scheduleDate = nil
                                repeatOption = Workout.RepeatOption.none 
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
                            selection: Binding(
                                get: { scheduleDate ?? Date() }, 
                                set: { scheduleDate = $0 }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("scheduleDatePicker")

                        Picker("Repeat", selection: $repeatOption.bound) {
                            ForEach(Workout.RepeatOption.allCases) { option in
                                Text(option.rawValue).tag(option as Workout.RepeatOption?)
                            }
                        }
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("repeatOptionPicker")
                    }
                }
                
                Section(header: Text("Exercises").font(.system(size: 18, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundStyle(selectedCategory?.categoryColor.color ?? .secondary)) {
                    ForEach($sortedExercises) { $exercise in
                        HStack {
                            TextField("Exercise (e.g., Push-ups 10x10)", text: $exercise.name)
                                .font(.system(.body, design: .serif))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.gray)
                                .font(.system(size: 18))
                        }
                    }
                    .onDelete { offsets in
                        sortedExercises.remove(atOffsets: offsets)
                        updateExerciseOrders()
                    }
                    .onMove(perform: moveExercises)
                    Button(action: {
                        let newExercise = Exercise(name: "", order: sortedExercises.count)
                        sortedExercises.append(newExercise)
                    }) {
                        Text("Add Exercise")
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(.blue)
                    }
                }
            }
            .navigationTitle("Edit Workout")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { 
                        save()
                    }) { 
                        Text("Save")
                            .font(.system(.body, design: .serif).weight(.medium))
                            .padding(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                            .background((selectedCategory?.categoryColor.color ?? Color.accentColor).opacity(0.15)) 
                            .foregroundColor(selectedCategory?.categoryColor.color ?? Color.accentColor) 
                            .cornerRadius(6)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPicker(selectedCategory: $selectedCategory) 
            }
        }
    }
    
    func moveExercises(from source: IndexSet, to destination: Int) {
        sortedExercises.move(fromOffsets: source, toOffset: destination)
        updateExerciseOrders()
    }
    
    func updateExerciseOrders() {
        for (index, exercise) in sortedExercises.enumerated() {
            exercise.order = index
        }
    }
    
    func save() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorManager.presentAlert(title: "Validation Error", message: "Workout title cannot be empty.")
            return
        }

        let oldScheduleDate = workout.scheduleDate
        let oldRepeatOption = workout.repeatOption

        workout.title = title
        workout.category = selectedCategory 
    
        let validExercises = sortedExercises.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        for (index, exercise) in validExercises.enumerated() {
            exercise.order = index
        }
        workout.exercises = validExercises
        
        workout.scheduleDate = scheduleDate
        if scheduleDate == nil { 
            workout.repeatOption = Workout.RepeatOption.none
        } else {
            workout.repeatOption = repeatOption 
        }
        
        let scheduleChanged = (oldScheduleDate != workout.scheduleDate) || (oldRepeatOption != workout.repeatOption)

        if !context.hasChanges { 
            if scheduleChanged {
                Task { 
                    await MainActor.run { 
                        NotificationManager.shared.scheduleOrUpdateNotification(for: workout)
                        errorManager.presentAlert(
                            title: "Schedule Updated",
                            message: "Workout schedule for '\(workout.title)' has been updated and notification rescheduled."
                        )
                    }
                }
                return
            }
            errorManager.presentAlert(title: "No Changes", message: "There were no changes to save for this workout.")
            return 
        }

        do {
            try context.save()
            Task { 
                await MainActor.run { 
                    NotificationManager.shared.scheduleOrUpdateNotification(for: workout)
                    errorManager.presentAlert(
                        title: "Workout Saved",
                        message: "Your workout '\(workout.title)' has been successfully updated."
                    )
                }
            }
        } catch {
            errorManager.presentAlert(
                title: "Save Error",
                message: "Failed to save workout: \(error.localizedDescription)"
            )
        }
    }
}

extension Optional where Wrapped: Hashable {
    var bound: Wrapped? {
        get { self }
        set { self = newValue }
    }
}

extension Binding where Value == Workout.RepeatOption? {
    var bound: Workout.RepeatOption {
        get { self.wrappedValue ?? .none }
        set { self.wrappedValue = newValue }
    }
}
