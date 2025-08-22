//
//  HistoryView.swift
//  MoveMD1.0
//
//  Created by Joseph DeWeese on 5/1/25.
//

import SwiftUI
import SwiftData

// enum HistoryMetricInfo: String, Identifiable { ... }

struct HistoryEntryView: View {
   
    @Bindable var history: History 
    let workout: Workout 
    
    @Environment(\.modelContext) private var modelContext 
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#929000" 
    
    @State private var journalText: String = ""
    @FocusState private var isJournalEditorFocused: Bool
    @State private var showMetricsInfoPopover: Bool = false

    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }
    
    private var categoryColor: Color {
        workout.category?.categoryColor.color ?? themeColor
    }

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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading) {
                    Text(workout.title)
                        .font(.headline) 
                        .fontWeight(.bold)
                        .foregroundStyle(categoryColor)
                    Text(history.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let categorySymbol = workout.category?.symbol {
                    Image(systemName: categorySymbol)
                        .font(.title2)
                        .foregroundStyle(categoryColor.opacity(0.7))
                }
            }
            .padding(.bottom, 5)

            Divider()

            if !history.splitTimes.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Split Times")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)
                    
                    ForEach(history.splitTimes) { splitTime in
                        if let exercise = splitTime.exercise {
                            HStack {
                                Image(systemName: "timer")
                                    .foregroundStyle(categoryColor.opacity(0.8))
                                Text("\(exercise.name):")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(formatTime(value: splitTime.durationInSeconds, isSeconds: true))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityIdentifier("splitTime_\(exercise.name)")
                        }
                    }
                }
                .padding(.bottom, 5)
                
                Divider()
            }

            HStack {
                Image(systemName: "clock.fill") 
                    .foregroundStyle(categoryColor)
                Text("Total Time:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
                Text(formatTime(value: history.lastSessionDuration))
                    .font(.headline.monospacedDigit()) 
                    .fontWeight(.medium)
                    .foregroundStyle(categoryColor)
            }

            if history.intensityScore != nil || history.progressPulseScore != nil || history.dominantZone != nil {
                Divider().padding(.vertical, 5)
                VStack(alignment: .leading, spacing: 8) { 
                    HStack {
                        Text("Advanced Metrics")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        Button { showMetricsInfoPopover = true } label: {
                            Image(systemName: "info.circle.fill") // Use filled icon for more visual weight
                                .font(.caption)
                                .foregroundColor(categoryColor) // Use category color for the main info button
                        }
                    }
                    .padding(.bottom, 2)

                    if let intensity = history.intensityScore {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(categoryColor.opacity(0.8))
                            Text("Intensity Score:")
                                .font(.subheadline)
                            Spacer()
                            Text("\(String(format: "%.0f", intensity))%")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let pulse = history.progressPulseScore {
                        HStack {
                            Image(systemName: "heart.text.clipboard.fill") 
                                .foregroundStyle(categoryColor.opacity(0.8))
                            Text("Progress Pulse:")
                                .font(.subheadline)
                            Spacer()
                            Text("\(String(format: "%.0f", pulse))")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let zone = history.dominantZone, let description = zoneDescription(for: zone) {
                        HStack {
                            Image(systemName: "figure.walk.motion")
                                .foregroundStyle(categoryColor.opacity(0.8))
                            Text("Dominant Zone:")
                                .font(.subheadline)
                            Spacer()
                            Text("\(zone) (\(description))")
                                .font(.subheadline) 
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .popover(isPresented: $showMetricsInfoPopover) {
                    ScrollView { // Add ScrollView for potentially longer text
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Advanced Metrics Explained")
                                .font(.title2.bold()) // More prominent title
                                .padding(.bottom, 5)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Intensity Score")
                                    .font(.headline)
                                Text("Reflects the cardiovascular challenge based on heart rate during the workout relative to your resting heart rate. Calculated using average workout heart rate and resting heart rate.")
                                    .font(.subheadline)
                            }
                            Divider()
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Progress Pulse Score (0-100)")
                                    .font(.headline)
                                Text("Indicates workout effectiveness. Considers:\n• Performance vs. Personal Best (time/duration)\n• Workout Frequency (vs. target per week)\n• Intensity (dominant heart rate zone achieved).")
                                    .font(.subheadline)
                            }
                            Divider()
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Dominant Heart Rate Zone (1-5)")
                                    .font(.headline)
                                Text("The zone (Very Light, Light, Moderate, Hard, Maximum) where you spent the most time. Calculated by analyzing heart rate samples against your max heart rate (estimated if not set).")
                                    .font(.subheadline)
                            }
                            
                            Spacer(minLength: 20) // Ensure some space before dismiss
                            
                            HStack {
                                Spacer()
                                Button("Dismiss") {
                                    showMetricsInfoPopover = false
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(categoryColor.opacity(0.2))
                                .clipShape(Capsule())
                                Spacer()
                            }
                        }
                        .padding()
                    }
                    .frame(minWidth: 300, idealWidth: 350, maxWidth: 450, minHeight: 250, idealHeight: 400, maxHeight: 500) // Adjusted frame for more content
                }
            }

            Divider().padding(.vertical, 5)
            
            VStack(alignment: .leading) {
                Text("Workout Journal")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)

                TextEditor(text: $journalText)
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .font(.body)
                    .focused($isJournalEditorFocused)
                    .onAppear {
                        journalText = history.notes ?? ""
                    }
                
                if journalText != (history.notes ?? "") || isJournalEditorFocused {
                    Button(action: {
                        saveJournalEntry()
                        isJournalEditorFocused = false 
                    }) {
                        Text("Save Journal")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(categoryColor)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 5)
                }
            }
        }
        .padding()
        .background(Material.thin)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
    }
    
    private func saveJournalEntry() {
        history.notes = journalText.isEmpty ? nil : journalText
        do {
            if modelContext.hasChanges { 
                try modelContext.save()
                print("Journal entry saved for history ID: \(history.id)")
            }
        } catch {
            print("Failed to save journal entry: \(error)")
        }
    }
    
    func formatTime(value: Double, isSeconds: Bool = false) -> String {
        let totalSeconds = isSeconds ? value : value * 60
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        let milliseconds = Int((totalSeconds - floor(totalSeconds)) * 100)
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%02d", hours, minutes, seconds, milliseconds)
        } else {
            return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
        }
    }
}

struct HistoryView: View {
    let workout: Workout
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#929000"
    
    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }
    
    private var categoryColor: Color {
        workout.category?.categoryColor.color ?? themeColor
    }

    var body: some View {
        NavigationStack {
            List {
                if workout.history.isEmpty {
                    ContentUnavailableView(
                        "No Workout History",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Complete a session for this workout to see its history here.")
                    )
                    .foregroundStyle(.secondary)
                } else {
                    ForEach(workout.history) { historyItem in
                        HistoryEntryView(history: historyItem, workout: workout)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Workout History")
            .tint(categoryColor)
            .toolbarColorScheme(categoryColor.isDark ? .dark : .light, for: .navigationBar)
        }
    }
}

extension Color {
    var isDark: Bool {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return false
        }
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance < 0.5
    }
}
