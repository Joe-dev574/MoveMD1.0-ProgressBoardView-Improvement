// ProgressBoardView.swift
import SwiftUI
import SwiftData
import HealthKit
import OSLog // Ensure OSLog is imported
import Combine

struct DayGridItem: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    var didWorkout: Bool
    let isToday: Bool
    var isTestWorkout: Bool
}

struct DayCellView: View {
    let didWorkout: Bool
    let isToday: Bool
    var themeColor: Color
    @State private var isPressed: Bool = false
    var isTestWorkout: Bool

    private var cellGradient: RadialGradient {
        if isTestWorkout {
            return RadialGradient(gradient: Gradient(colors: [.white.opacity(0.5), .indigo, .indigo]), center: .init(x: 0.3, y: 0.3), startRadius: 0, endRadius: 10)
        } else if didWorkout {
            return RadialGradient(gradient: Gradient(colors: [.white.opacity(0.5), .green, .green]), center: .init(x: 0.3, y: 0.3), startRadius: 0, endRadius: 10)
        } else {
            return RadialGradient(gradient: Gradient(colors: [.white.opacity(0.2), .gray.opacity(0.2)]), center: .init(x: 0.3, y: 0.3), startRadius: 0, endRadius: 10)
        }
    }

    var body: some View {
        Circle()
            .fill(cellGradient)
            .frame(width: 20, height: 20)
            .overlay(
                isToday ? Circle().stroke(themeColor, lineWidth: 3) : nil
            )
            .shadow(color: .black.opacity(didWorkout ? 0.3 : 0.1), radius: 2, x: 2, y: 2)
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .onTapGesture {
                withAnimation {
                    isPressed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isPressed = false
                    }
                }
            }
            .accessibilityLabel(isToday ? "Today, \(didWorkout ? "Workout completed" : "No workout")" : didWorkout ? "Workout completed" : "No workout")
            .accessibilityHint(didWorkout ? "Tap to highlight workout day" : "Tap to highlight non-workout day")
    }
}

struct WorkoutGraph: View {
    let values: [Double]
    let themeColor: Color
    let title: String
    var fixedMaxValue: Double? = nil

    private var effectiveMaxValue: Double {
        let dataMax = values.isEmpty ? 1.0 : (values.max() ?? 1.0)
        let yAxisMax = fixedMaxValue ?? dataMax
        return max(yAxisMax, 1.0)
    }

    private let leadingPaddingForLabels: CGFloat = 35
    private let trailingPadding: CGFloat = 10
    private let topPadding: CGFloat = 5
    private let bottomPadding: CGFloat = 5
    private let labelWidth: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(themeColor)
                .padding(.leading, leadingPaddingForLabels)

            GeometryReader { geometry in
                let availableWidth = geometry.size.width - leadingPaddingForLabels - trailingPadding
                let availableHeight = geometry.size.height - topPadding - bottomPadding
                let drawableHeight = max(0, availableHeight)
                let drawableWidth = max(0, availableWidth)

                let dataPointSpacing = (values.count > 1) ? (drawableWidth / CGFloat(values.count - 1)) : 0

                ZStack(alignment: .leading) {
                    ForEach(0...3, id: \.self) { i in
                        let yPos = topPadding + (drawableHeight * CGFloat(i) / 3.0)
                        let lineValue = effectiveMaxValue * (1.0 - CGFloat(i) / 3.0)

                        Path { path in
                            path.move(to: CGPoint(x: leadingPaddingForLabels, y: yPos))
                            path.addLine(to: CGPoint(x: geometry.size.width - trailingPadding, y: yPos))
                        }
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)

                        if drawableHeight > 10 {
                            Text(String(format: "%.0f", lineValue))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: labelWidth, alignment: .trailing)
                                .position(x: leadingPaddingForLabels / 2 , y: yPos)
                        }
                    }

                    Group {
                        Path { path in
                            path.move(to: CGPoint(x: leadingPaddingForLabels, y: topPadding + drawableHeight))

                            for (index, value) in values.enumerated() {
                                let x = leadingPaddingForLabels + (values.count > 1 ? CGFloat(index) * dataPointSpacing : drawableWidth / 2)
                                let normalizedValue = max(0, min(CGFloat(value) / CGFloat(effectiveMaxValue), 1.0))
                                let yValue = topPadding + drawableHeight * (1.0 - normalizedValue)

                                if index == 0 && values.count > 1 {
                                     path.addLine(to: CGPoint(x: x, y: topPadding + drawableHeight))
                                }
                                path.addLine(to: CGPoint(x: x, y: yValue))
                            }

                            if !values.isEmpty {
                                let lastX = leadingPaddingForLabels + (values.count > 1 ? CGFloat(values.count - 1) * dataPointSpacing : drawableWidth / 2)
                                path.addLine(to: CGPoint(x: lastX, y: topPadding + drawableHeight))
                            }
                            path.closeSubpath()
                        }
                        .fill(LinearGradient(gradient: Gradient(colors: [themeColor.opacity(0.4), themeColor.opacity(0.05)]), startPoint: .top, endPoint: .bottom))

                        Path { path in
                            guard !values.isEmpty else { return }

                            for (index, value) in values.enumerated() {
                                let x = leadingPaddingForLabels + (values.count > 1 ? CGFloat(index) * dataPointSpacing : drawableWidth / 2)
                                let normalizedValue = max(0, min(CGFloat(value) / CGFloat(effectiveMaxValue), 1.0))
                                let yValue = topPadding + drawableHeight * (1.0 - normalizedValue)

                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: yValue))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: yValue))
                                }
                            }
                        }
                        .stroke(themeColor, lineWidth: 2)
                        .shadow(color: themeColor.opacity(0.3), radius: 3, y: 2)

                        ForEach(values.indices, id: \.self) { index in
                            let x = leadingPaddingForLabels + (values.count > 1 ? CGFloat(index) * dataPointSpacing : drawableWidth / 2)
                            let normalizedValue = max(0, min(CGFloat(values[index]) / CGFloat(effectiveMaxValue), 1.0))
                            let yValue = topPadding + drawableHeight * (1.0 - normalizedValue)
                            Circle()
                                .fill(themeColor)
                                .frame(width: 6, height: 6)
                                .position(x: x, y: yValue)
                                .shadow(color: .black.opacity(0.1), radius: 1)
                        }
                    }
                }
            }
        }
    }
}

enum InfoStatItem: String, Identifiable {
    case totalWorkouts, totalTime, avgWorkoutsPerWeek, activeDays
    // Add more cases here if you add more info icons for other stats

    var id: String { self.rawValue }

    // Helper to get the descriptive text for each stat
    var descriptionText: String {
        switch self {
        case .totalWorkouts:
            return "The total number of workouts completed in the last 90 days."
        case .totalTime:
            return "The total duration of all workouts completed in the last 90 days."
        case .avgWorkoutsPerWeek:
            return "The average number of workouts completed per week over the last 90 days."
        case .activeDays:
            return "The number of unique days you completed at least one workout in the last 90 days."
        }
    }

    // Helper to get the display title (optional, if different from rawValue or needed for UI)
    var displayTitle: String {
        switch self {
        case .totalWorkouts: return "Total Workouts"
        case .totalTime: return "Total Time"
        case .avgWorkoutsPerWeek: return "Avg Workouts/Wk"
        case .activeDays: return "Active Days"
        }
    }
}

struct ProgressBoardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKitManager: HealthKitManager // Keep
    @EnvironmentObject var errorManager: ErrorManager
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    private var themeColor: Color { Color(hex: selectedThemeColorData) ?? .blue }
    
    @State private var workoutDates: Set<DateComponents> = [] // Can potentially be removed if not used elsewhere
    @State private var daysToDisplay: [DayGridItem] = []
    @State private var weeklyDurations: [Double] = []
    @State private var weeklyWorkoutCounts: [Int] = []
    @State private var weeklyProgressPulseScores: [Double] = []
    
    @State private var totalWorkoutsLast90Days: Int = 0
    @State private var totalDurationLast90DaysFormatted: String = "0 min"
    @State private var avgWorkoutsPerWeekLast90Days: Double = 0.0
    @State private var distinctActiveDaysLast90Days: Int = 0
    
    @State private var latestCategoryMetrics: [String: WorkoutMetrics] = [:] // Keep
    @State private var isLoading: Bool = false
    
    @State private var activeInfoPopover: InfoStatItem?
    
    private let calendar = Calendar.current
    private let gridColumns: [GridItem] = Array(repeating: GridItem(.fixed(25), spacing: 5), count: 7)
    private let logger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.movemd.default.subsystem", category: "ProgressBoardView")
    @State private var cancellables = Set<AnyCancellable>()
    
    struct WorkoutMetrics {
        let intensityScore: Double?
        let progressPulseScore: Double?
        let dominantZone: Int?
    }
    
    private var activityDateRangeString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        
        let today = calendar.startOfDay(for: Date())
        guard let startDateOfHeatmap = calendar.date(byAdding: .day, value: -89, to: today) else {
            let currentDayString = dateFormatter.string(from: today)
            logger.error("[ProgressBoardView] Failed to calculate startDateOfHeatmap for activityDateRangeString.")
            return currentDayString
        }
        
        let startDayString = dateFormatter.string(from: startDateOfHeatmap)
        let endDayString = dateFormatter.string(from: today)
        
        return "\(startDayString) - \(endDayString)"
    }
    
    private func heatMapLegend() -> some View {
        HStack(spacing: 15) {
            Spacer()
            HStack(spacing: 5) {
                DayCellView(didWorkout: true, isToday: false, themeColor: themeColor, isTestWorkout: false)
                Text("Workout")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 5) {
                DayCellView(didWorkout: true, isToday: false, themeColor: themeColor, isTestWorkout: true)
                Text("Test")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 5) {
                DayCellView(didWorkout: false, isToday: false, themeColor: themeColor, isTestWorkout: false)
                Text("No Workout")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(themeColor, lineWidth: 3)) //LineWidth already updated
                Text("Today")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.bottom, 5)
    }

    private var heatmapView: some View {
        LazyVGrid(columns: gridColumns, spacing: 5) {
            ForEach(daysToDisplay) { item in
                DayCellView(
                    didWorkout: item.didWorkout,
                    isToday: item.isToday,
                    themeColor: themeColor,
                    isTestWorkout: item.isTestWorkout
                )
            }
        }
        .padding(8)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workout heatmap for the last 90 days. Green indicates workout, blue indicates test workout, gray indicates no workout. Today is circled with a thicker border.")
    }

    @ViewBuilder
    private func statItem(title: String, value: String, statIdentifier: InfoStatItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button {
                    activeInfoPopover = statIdentifier // Set the active popover item
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(themeColor)
                .lineLimit(2)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .center, spacing: 12) {
                    Text("90 Day Activity: \(activityDateRangeString)")
                        .font(.headline)
                        .foregroundColor(themeColor)
                        .accessibilityAddTraits(.isHeader)
                    
                    heatMapLegend()
                    
                    if isLoading && daysToDisplay.isEmpty {
                        ProgressView("Loading Activity...")
                            .padding()
                    } else if daysToDisplay.isEmpty && !isLoading {
                        Text("No workouts recorded in the last 90 days. Start tracking to see your progress!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                            .accessibilityLabel("No workout data found for the last 90 days.")
                    } else {
                        HStack(alignment: .top, spacing: 15) { // Changed to .top alignment
                            // VStack for all stats on the left
                            VStack(alignment: .leading, spacing: 15) { // Increased spacing between stat items
                                statItem(
                                    title: InfoStatItem.totalWorkouts.displayTitle,
                                    value: "\(totalWorkoutsLast90Days)",
                                    statIdentifier: .totalWorkouts
                                )
                                
                                statItem(
                                    title: InfoStatItem.totalTime.displayTitle,
                                    value: totalDurationLast90DaysFormatted,
                                    statIdentifier: .totalTime
                                )
                                
                                statItem(
                                    title: InfoStatItem.avgWorkoutsPerWeek.displayTitle,
                                    value: String(format: "%.1f", avgWorkoutsPerWeekLast90Days),
                                    statIdentifier: .avgWorkoutsPerWeek
                                )
                                
                                statItem(
                                    title: InfoStatItem.activeDays.displayTitle,
                                    value: "\(distinctActiveDaysLast90Days)",
                                    statIdentifier: .activeDays
                                )
                            }
                            .frame(minWidth: 120, idealWidth: 150) // Give stats some width
                            .padding(.leading) // Add some padding to the stats column
                            .popover(item: $activeInfoPopover) { item in
                                VStack(alignment: .leading) { // Changed to leading alignment for better text flow
                                    Text(item.displayTitle)
                                        .font(.headline)
                                        .padding(.bottom, 5)
                                    Text(item.descriptionText)
                                        .font(.body)
                                    Spacer()
                                    HStack { // Center the dismiss button
                                        Spacer()
                                        Button("Dismiss") {
                                            activeInfoPopover = nil
                                        }
                                        Spacer()
                                    }
                                    .padding(.top)
                                }
                                .padding()
                                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400, minHeight: 120, idealHeight: 180) // Adjusted frame
                            }

                            // Heatmap pushed to the right by the stats
                            // The heatmap itself will take up the remaining flexible space if not constrained.
                            // We might need to constrain the heatmap's width or the stats VStack's width more explicitly
                            // if the Spacer doesn't behave as expected, or use .frame(maxWidth: .infinity) on the heatmap side.
                            heatmapView
                                .frame(maxWidth: .infinity, alignment: .center) // Allow heatmap to take available space but center it

                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        
                        // Graphs follow
                        if !weeklyDurations.isEmpty {
                            WorkoutGraph(
                                values: weeklyDurations,
                                themeColor: themeColor,
                                title: "Weekly Workout Duration (Mins)",
                                fixedMaxValue: 450.0 
                            )
                            .frame(height: 150)
                            .padding(.horizontal, 8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .opacity(isLoading ? 0.5 : 1)
                            .animation(.easeIn(duration: 0.3), value: isLoading)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Graph showing weekly workout duration in minutes over the last 12 weeks.")
                        }
                        
                        if !weeklyWorkoutCounts.isEmpty {
                            WorkoutGraph(
                                values: weeklyWorkoutCounts.map { Double($0) },
                                themeColor: themeColor,
                                title: "Weekly Workout Count",
                                fixedMaxValue: max(Double(weeklyWorkoutCounts.max() ?? 0), 7.0) * 1.2
                            )
                            .frame(height: 150)
                            .padding(.horizontal, 8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .opacity(isLoading ? 0.5 : 1)
                            .animation(.easeIn(duration: 0.3), value: isLoading)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Graph showing number of workouts per week over the last 12 weeks.")
                        }

                        if !weeklyProgressPulseScores.isEmpty {
                            WorkoutGraph(
                                values: weeklyProgressPulseScores,
                                themeColor: themeColor,
                                title: "Weekly Progress Pulse Score",
                                fixedMaxValue: 100.0
                            )
                            .frame(height: 150)
                            .padding(.horizontal, 8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .opacity(isLoading ? 0.5 : 1)
                            .animation(.easeIn(duration: 0.3), value: isLoading)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Graph showing weekly progress pulse score over the last 12 weeks.")
                        }
                        
                        if healthKitManager.isAuthorized {
                            if !latestCategoryMetrics.isEmpty {
                                Section(header: Text("Latest Workout Metrics").font(.headline).foregroundColor(themeColor)) {
                                    ForEach(latestCategoryMetrics.keys.sorted(), id: \.self) { categoryName in
                                        if let metrics = latestCategoryMetrics[categoryName] {
                                            VStack(alignment: .leading) {
                                                Text(categoryName).font(.subheadline).bold()
                                                HStack {
                                                    if let score = metrics.intensityScore { Text("Intensity: \(Int(score))%") }
                                                    if let score = metrics.progressPulseScore { Text("Pulse: \(Int(score))") }
                                                    if let zone = metrics.dominantZone { Text("Zone: \(zone) (\(zoneDescription(zone)))") }
                                                }
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding(.top)
                                
                            } else if !isLoading {
                                Text("Complete a workout to see advanced metrics.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top)
                            }
                        } else {
                            Text("Authorize HealthKit in Settings to view advanced metrics.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .navigationTitle("Activity")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoading {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .onAppear {
                if cancellables.isEmpty { 
                    NotificationCenter.default.publisher(for: .workoutDidComplete)
                        .receive(on: DispatchQueue.main)
                        .sink { _ in
                            logger.debug("[ProgressBoardView] Received .workoutDidComplete notification. Refreshing board.")
                            Task {
                                await refreshBoard()
                            }
                        }
                        .store(in: &cancellables)
                    logger.debug("[ProgressBoardView] onAppear: .workoutDidComplete observer set up.")
                }

                if daysToDisplay.isEmpty {
                    logger.debug("[ProgressBoardView] onAppear: Initializing board data.")
                    initializeBoard()
                } else {
                    logger.debug("[ProgressBoardView] onAppear: Data already loaded, skipping initial fetch.")
                }
            }
            .refreshable {
                logger.debug("[ProgressBoardView] Refresh triggered.")
                await refreshBoard()
            }
            .background(Color(UIColor.systemBackground))
            .onDisappear {
                logger.debug("[ProgressBoardView] onDisappear: Cancellables count: \(cancellables.count).")
            }
        }
        .navigationViewStyle(.stack)
        .tint(themeColor)
    }
    
    private func initializeBoard() {
        isLoading = true
        logger.debug("[ProgressBoardView] [initializeBoard] Called. HealthKit Authorized: \(self.healthKitManager.isAuthorized)")
        Task {
            await fetchHistoryDataAsync()
            if healthKitManager.isAuthorized {
                logger.debug("[ProgressBoardView] [initializeBoard] HealthKit is authorized, calling fetchLatestMetrics().")
                await fetchLatestMetrics()
            } else { 
                await MainActor.run {
                    self.latestCategoryMetrics = [:]
                    logger.debug("[ProgressBoardView] [initializeBoard] HealthKit NOT authorized, clearing latestCategoryMetrics.")
                    if self.isLoading { self.isLoading = false } 
                }
            }
        }
    }
    
    private func refreshBoard() async {
        logger.debug("[ProgressBoardView] [refreshBoard] Called. HealthKit Authorized: \(self.healthKitManager.isAuthorized)")
        await fetchHistoryDataAsync()
        if healthKitManager.isAuthorized {
            logger.debug("[ProgressBoardView] [refreshBoard] HealthKit is authorized, calling fetchLatestMetrics().")
            await fetchLatestMetrics()
        } else {
            await MainActor.run {
                self.latestCategoryMetrics = [:]
                logger.debug("[ProgressBoardView] [refreshBoard] HealthKit NOT authorized, clearing latestCategoryMetrics.")
            }
        }
    }
    
    private func fetchHistoryDataAsync() async {
        await MainActor.run { self.isLoading = true } 
        logger.debug("[ProgressBoardView] [fetchHistoryDataAsync] Starting fetch. isLoading set to true.")
        
        let now = Date()
        let endOfTodayForPredicate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
        
        let startOfToday = calendar.startOfDay(for: now)
        guard let historyFetchStartDate = calendar.date(byAdding: .day, value: -89, to: startOfToday) else {
            logger.error("[ProgressBoardView] [fetchHistoryDataAsync] Failed to calculate history fetch start date.")
            await MainActor.run {
                errorManager.presentAlert(title: "Error", message: "Failed to calculate date range for history.")
                self.isLoading = false
            }
            return
        }
        
        logger.debug("[ProgressBoardView] [fetchHistoryDataAsync] Fetching history from: \(historyFetchStartDate.formatted(date: .long, time: .standard)) up to (but not including): \(endOfTodayForPredicate.formatted(date: .long, time: .standard)) for graphs and heatmap.")

        let predicate = #Predicate<History> { history in
            history.date >= historyFetchStartDate && history.date < endOfTodayForPredicate 
        }
        
        var descriptor = FetchDescriptor<History>(predicate: predicate, sortBy: [SortDescriptor(\History.date)])
        descriptor.relationshipKeyPathsForPrefetching = [\History.workout]
        
        do {
            let histories = try modelContext.fetch(descriptor)
            logger.log("[ProgressBoardView] [fetchHistoryDataAsync] Fetched \(histories.count) history records with predicate for the last 90 days.")
            
            var calculatedDaysToDisplay: [DayGridItem] = []
            guard let heatmapStartDate = calendar.date(byAdding: .day, value: -89, to: startOfToday) else {
                logger.error("[ProgressBoardView] [fetchHistoryDataAsync] Failed to calculate heatmapStartDate for display loop.")
                await MainActor.run {
                    errorManager.presentAlert(title: "Error", message: "Date calculation error.")
                    self.isLoading = false
                }
                return
            }

            var currentDateIterator = heatmapStartDate
            for i in 0..<90 {
                let displayDate = calendar.startOfDay(for: currentDateIterator)
                let isCurrentItemToday = calendar.isDate(displayDate, inSameDayAs: startOfToday)
                
                let didWorkoutOnThisDay = histories.contains(where: { calendar.isDate($0.date, inSameDayAs: displayDate) })
                let isTestWorkoutOnThisDay = histories.first(where: { calendar.isDate($0.date, inSameDayAs: displayDate) })?.workout?.title.lowercased().contains("test") ?? false

                calculatedDaysToDisplay.append(DayGridItem(
                    date: displayDate, 
                    didWorkout: didWorkoutOnThisDay, 
                    isToday: isCurrentItemToday,
                    isTestWorkout: isTestWorkoutOnThisDay 
                ))
                if i < 89 {
                   currentDateIterator = calendar.date(byAdding: .day, value: 1, to: currentDateIterator)!
                }
            }
            logger.debug("[ProgressBoardView] [fetchHistoryDataAsync] Calculated \(calculatedDaysToDisplay.count) days for heatmap display. First: \(calculatedDaysToDisplay.first?.date.description ?? "N/A"), Last: \(calculatedDaysToDisplay.last?.date.description ?? "N/A")")

            let calculatedTotalWorkouts90Days = histories.count
            let totalDurationMinutes90Days = histories.reduce(0.0) { $0 + $1.lastSessionDuration }
            
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute]
            formatter.unitsStyle = .abbreviated
            let calculatedTotalDurationFormatted = formatter.string(from: TimeInterval(totalDurationMinutes90Days * 60)) ?? "\(Int(totalDurationMinutes90Days)) min"
            
            let numberOfWeeksIn90Days = 90.0 / 7.0 
            let calculatedAvgWorkoutsPerWeek = Double(calculatedTotalWorkouts90Days) / numberOfWeeksIn90Days
            
            var distinctDays = Set<DateComponents>()
            for historyItem in histories {
                distinctDays.insert(calendar.dateComponents([.year, .month, .day], from: historyItem.date))
            }
            let calculatedDistinctActiveDays = distinctDays.count

            let calculatedWeeklyDurations: [Double] = (0..<12).map { weekIndex -> Double in
                let endOfWeekDay = calendar.date(byAdding: .day, value: -(weekIndex * 7), to: startOfToday)!
                let startOfWeekDay = calendar.date(byAdding: .day, value: -6, to: endOfWeekDay)!
                return histories.filter { history in
                    let historyDay = calendar.startOfDay(for: history.date)
                    return historyDay >= startOfWeekDay && historyDay <= endOfWeekDay
                }.reduce(0.0) { $0 + $1.lastSessionDuration }
            }.reversed()
            
            let calculatedWeeklyWorkoutCounts: [Int] = (0..<12).map { weekIndex in
                let endOfWeekDay = calendar.date(byAdding: .day, value: -(weekIndex * 7), to: startOfToday)!
                let startOfWeekDay = calendar.date(byAdding: .day, value: -6, to: endOfWeekDay)!
                return histories.filter { history in
                    let historyDate = calendar.startOfDay(for: history.date)
                    return historyDate >= startOfWeekDay && historyDate <= endOfWeekDay
                }.count
            }.reversed()

            let calculatedWeeklyProgressPulseScores: [Double] = (0..<12).map { weekIndex -> Double in
                let endOfWeekDay = calendar.date(byAdding: .day, value: -(weekIndex * 7), to: startOfToday)!
                let startOfWeekDay = calendar.date(byAdding: .day, value: -6, to: endOfWeekDay)!
                let scoresInWeek = histories.filter { history in
                    let historyDay = calendar.startOfDay(for: history.date)
                    return historyDay >= startOfWeekDay && historyDay <= endOfWeekDay && history.progressPulseScore != nil
                }.compactMap { $0.progressPulseScore }
                return scoresInWeek.isEmpty ? 0.0 : scoresInWeek.reduce(0.0, +) / Double(scoresInWeek.count)
            }.reversed()
            
            await MainActor.run {
                self.daysToDisplay = calculatedDaysToDisplay
                self.weeklyDurations = calculatedWeeklyDurations
                self.weeklyWorkoutCounts = calculatedWeeklyWorkoutCounts
                self.weeklyProgressPulseScores = calculatedWeeklyProgressPulseScores
                
                self.totalWorkoutsLast90Days = calculatedTotalWorkouts90Days
                self.totalDurationLast90DaysFormatted = calculatedTotalDurationFormatted
                self.avgWorkoutsPerWeekLast90Days = calculatedAvgWorkoutsPerWeek
                self.distinctActiveDaysLast90Days = calculatedDistinctActiveDays
                
                self.isLoading = false
                logger.log("[ProgressBoardView] [fetchHistoryDataAsync] History data processed. Weekly Pulse Scores: \(calculatedWeeklyProgressPulseScores), Total 90-day Workouts: \(calculatedTotalWorkouts90Days)")
            }
            
        } catch {
            logger.error("[ProgressBoardView] [fetchHistoryDataAsync] Failed to fetch history: \(error.localizedDescription)")
            await MainActor.run {
                errorManager.presentAlert(title: "Error", message: "Failed to load activity data: \(error.localizedDescription)")
                self.isLoading = false
            }
        }
    }

    private func fetchLatestMetrics() async {
        logger.debug("[ProgressBoardView] [fetchLatestMetrics] Fetching latest metrics per category.")
        
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -89, to: today) else { // Ensure this aligns with historyFetchStartDate
            logger.error("[ProgressBoardView] [fetchLatestMetrics] Failed to calculate start date.")
            return
        }
        
        let predicate = #Predicate<History> { history in
            history.date >= startDate && history.date <= today &&
            (history.intensityScore != nil || history.progressPulseScore != nil || history.dominantZone != nil)
        }
        
        var descriptor = FetchDescriptor<History>(predicate: predicate, sortBy: [SortDescriptor(\History.date, order: .reverse)])
        descriptor.relationshipKeyPathsForPrefetching = [\History.workout?.category]
        
        do {
            let historiesWithMetrics = try modelContext.fetch(descriptor)
            logger.debug("[ProgressBoardView] [fetchLatestMetrics] Fetched \(historiesWithMetrics.count) histories potentially containing metrics for predicate.")
            
            let latestHistoryPerCategory = Dictionary(grouping: historiesWithMetrics, by: { $0.workout?.category?.categoryName ?? "Uncategorized" })
                .compactMapValues { $0.first }
            
            var newMetrics: [String: WorkoutMetrics] = [:]
            for (categoryName, latestHistory) in latestHistoryPerCategory {
                logger.trace("[ProgressBoardView] [fetchLatestMetrics] Latest metrics for category '\(categoryName)' from history date: \(latestHistory.date), Intensity: \(latestHistory.intensityScore ?? -1), Pulse: \(latestHistory.progressPulseScore ?? -1), Zone: \(latestHistory.dominantZone ?? -1)")
                newMetrics[categoryName] = WorkoutMetrics(
                    intensityScore: latestHistory.intensityScore,
                    progressPulseScore: latestHistory.progressPulseScore,
                    dominantZone: latestHistory.dominantZone
                )
            }
            
            await MainActor.run {
                self.latestCategoryMetrics = newMetrics
                logger.debug("[ProgressBoardView] [fetchLatestMetrics] Latest metrics updated. Count: \(newMetrics.count). Keys: \(newMetrics.keys.joined(separator: ", "))")
            }
        } catch {
            logger.error("[ProgressBoardView] [fetchLatestMetrics] Failed to fetch histories for metrics: \(error.localizedDescription)")
        }
    }
    
    private func fetchCategories() -> [Category] {
        let descriptor = FetchDescriptor<Category>()
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch categories: \(error)")
            return []
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
    
#if DEBUG
    struct ProgressBoardView_Previews: PreviewProvider {
        @MainActor static var previews: some View {
            let container = PersistenceController.previewContainer // Ensure this is set up correctly
            
            // Sample data for preview
            let workout = Workout(title: "Preview Workout", dateCreated: Date())
            let category = Category(categoryName: "Preview Category", symbol: "figure.walk", categoryColor: .RUN)
            workout.category = category
            container.mainContext.insert(workout)
            container.mainContext.insert(category)

            let today = Calendar.current.startOfDay(for: Date())
            for i in 0..<20 { // Add some history data for preview
                if i % 3 == 0 { // Every 3rd day has a workout
                    let historyDate = Calendar.current.date(byAdding: .day, value: -(i * 3), to: today)!
                     let historyItem = History(date: historyDate, exercisesCompleted: [], splitTimes: [], lastSessionDuration: Double.random(in: 20...60))
                    historyItem.workout = workout
                    historyItem.progressPulseScore = Double.random(in: 40...90)
                    historyItem.intensityScore = Double.random(in: 50...80)
                    historyItem.dominantZone = Int.random(in: 2...4)
                    container.mainContext.insert(historyItem)
                }
            }
            
            let healthKitManager = HealthKitManager.shared
            healthKitManager.configureWithModelContext(container.mainContext) // Configure HKM for preview
            healthKitManager.isAuthorized = true // Assume authorized for preview
            
            return ProgressBoardView()
                .modelContainer(container)
                .environmentObject(healthKitManager)
        }
    }
#endif
}
