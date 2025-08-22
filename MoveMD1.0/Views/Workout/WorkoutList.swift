//
//  WorkoutList.swift
//  MoveMD1.0
//
//  Created by Joseph DeWeese on 4/29/25.
//
import SwiftUI
import SwiftData

struct WorkoutList: View {
    @Environment(\.modelContext) private var modelContext
    var workouts: [MoveMD1_0.Workout]
    
    var body: some View {
        if workouts.isEmpty {
            VStack {
                Image(systemName: "tray")
                    .resizable()
                    .foregroundStyle(.secondary)
                    .frame(width: 80, height: 60)
                Text("Empty workout file.")
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(.secondary)
                Text("Tap the '+' button to add a new workout.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(Color.clear)
        } else {
            List {
                ForEach(workouts) { workout in 
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        WorkoutCard(workout: workout)
                    }
                    .accessibilityIdentifier("workoutCard_\(workout.title)")
                    .listRowBackground(Color.clear)
                }
                .onDelete { offsets in
                    for index in offsets {
                        modelContext.delete(workouts[index])
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
    }
}
