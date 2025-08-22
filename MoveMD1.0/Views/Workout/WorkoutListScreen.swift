//
//  WorkoutListScreen.swift
//  MoveMD1.0
//
//  Created by Joseph DeWeese on 4/29/25.
//

import SwiftUI
import SwiftData

enum WorkoutFilterType: String, CaseIterable, Identifiable {
    case all = "All"
    case scheduled = "Scheduled"
    case category = "Category"
    var id: String { self.rawValue }
}

struct WorkoutListScreen: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    @Query(sort: \MoveMD1_0.Workout.dateCreated, order: .reverse) private var allWorkouts: [MoveMD1_0.Workout]
    
    @State private var currentDate = Date()
    @State private var showAddWorkoutSheet = false
    @State private var showProgressBoardSheet = false
    @State private var selectedFilter: WorkoutFilterType = .all
    @State private var categoryToFilterBy: Category? = nil
    @State private var showingCategoryPickerSheet = false
    
    @EnvironmentObject var authManager: AuthenticationManager
    
    private var filteredWorkouts: [MoveMD1_0.Workout] {
        switch selectedFilter {
        case .all:
            return allWorkouts.sorted(by: { $0.dateCreated > $1.dateCreated })
        case .scheduled:
            return allWorkouts.filter { workout in
                guard let date = workout.scheduleDate else { return false }
                return date >= Calendar.current.startOfDay(for: Date()) 
            }.sorted(by: { $0.scheduleDate ?? Date.distantFuture < $1.scheduleDate ?? Date.distantFuture })
        case .category:
            if let categoryToFilterBy {
                return allWorkouts.filter { $0.category == categoryToFilterBy }
                                  .sorted(by: { $0.dateCreated > $1.dateCreated })
            } else {
                return [] 
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack { 
                LinearGradient(
                    gradient: Gradient(colors: [.gray.opacity(0.02), .gray.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(WorkoutFilterType.allCases) { filterType in
                            Button(action: {
                                selectedFilter = filterType
                                if filterType == .category {
                                    showingCategoryPickerSheet = true
                                }
                            }) {
                                Text(filterType == .category ? (categoryToFilterBy?.categoryName ?? "Category") : filterType.rawValue)
                                    .font(.system(.headline, design: .serif))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: .infinity)
                                    .background(selectedFilter == filterType ? (Color(hex: selectedThemeColorData) ?? .blue).opacity(0.2) : Color.clear)
                                    .foregroundColor(selectedFilter == filterType ? (Color(hex: selectedThemeColorData) ?? .blue) : .gray)
                                    .contentShape(Rectangle()) 
                            }
                            if filterType != WorkoutFilterType.allCases.last {
                                Divider().frame(height: 20) 
                            }
                        }
                    }
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 5)

                    WorkoutList(workouts: filteredWorkouts)
                }
                .frame(maxWidth: .infinity) 

                VStack { 
                    Spacer() 
                    HStack { 
                        Spacer()
                        addWorkoutButton 
                        Spacer()
                    }
                }
                .padding(.bottom, 20) 
            }
            .toolbar(content: toolbarContent)
            .toolbarBackground(Color.clear, for: .navigationBar) 
            .sheet(isPresented: $showAddWorkoutSheet) {
                AddWorkoutView()
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showProgressBoardSheet) {
                ProgressBoardView()
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showingCategoryPickerSheet) {
                CategoryPicker(selectedCategory: $categoryToFilterBy)
                    .presentationDetents([.medium, .large]) 
                    .onDisappear {
                        if categoryToFilterBy != nil {
                            selectedFilter = .category
                        } else if selectedFilter == .category && categoryToFilterBy == nil {
                        }
                    }
            }
        }
    }
    
    private var addWorkoutButton: some View {
        Button(action: {
            showAddWorkoutSheet = true
        }) {
            Image(systemName: "plus")
                .font(.callout)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 45, height: 45)
                .background(Color(hex: selectedThemeColorData) ?? .blue)
                .clipShape(Circle())
        }
        .accessibilityIdentifier("plus")
    }
    
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            HStack { 
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gear")
                        .font(.title2)
                        .foregroundStyle(Color(hex: selectedThemeColorData) ?? .blue)
                        .padding(.bottom, 2)
                }
                .accessibilityIdentifier("gear")
                .accessibilityLabel("Settings")

                Button {
                    showProgressBoardSheet = true
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.title2)
                        .foregroundStyle(Color(hex: selectedThemeColorData) ?? .blue)
                        .padding(.bottom, 2)
                }
                .accessibilityIdentifier("progressBoardButton")
                .accessibilityLabel("Progress Board")
            }
        }
        ToolbarItem(placement: .principal) {
            VStack(alignment: .leading, spacing: 2) {
                Text(currentDate.format("MMMM YYYY"))
                    .font(.title2.bold())
                    .fontDesign(.serif)
                    .foregroundStyle(Color(hex: selectedThemeColorData) ?? .blue)
                Text(currentDate.format("EEEE, d"))
                    .font(.callout)
                    .fontDesign(.serif)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 7)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            NavigationLink(destination: ProfileView()) {
                if let currentUser = authManager.currentAppleUser, 
                   let imageData = currentUser.profileImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 35, height: 35)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(hex: selectedThemeColorData) ?? .blue))
                    
                } else {
                    Image(systemName: "person.circle")
                        .font(.title2)
                        .foregroundStyle(Color(hex: selectedThemeColorData) ?? .blue)
                }
            }
            .accessibilityIdentifier("person.circle")
            .accessibilityLabel("Profile")
        }
    }
}
