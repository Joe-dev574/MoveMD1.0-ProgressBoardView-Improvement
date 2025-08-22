// HealthMetricsSectionView.swift
import SwiftUI
import SwiftData

struct HealthMetricsSectionView: View {
    @Bindable var user: User
    @StateObject private var healthKitManager = HealthKitManager.shared // This creates a new instance. Consider passing it as @ObservedObject or @EnvironmentObject if a shared instance is needed. For now, using its .isAuthorized property might be okay if that reflects global state.
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
    
    var themeColor: Color
    
    @Binding var weightString: String
    @Binding var heightString: String
    @Binding var maxHRString: String
    var isLoading: Bool

    private var healthFieldsEditable: Bool {
        // If loading, treat fields as non-editable temporarily to avoid interaction issues
        if isLoading { return false }
        return !healthKitManager.isAuthorized
    }

    var body: some View {
        Section(header: Text("HEALTH METRICS")
            .font(.system(size: 18, design: .serif))
            .fontWeight(.semibold)
            .foregroundColor(themeColor)
        ) {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading Health Data...")
                        .fontDesign(.serif)
                    Spacer()
                }
                .padding(.vertical)
            } else {
                // Existing content
                HStack {
                    Text("Age")
                        .fontDesign(.serif)
                    Spacer()
                    Text(user.age != nil ? "\(user.age!) years" : "N/A")
                        .foregroundStyle(.secondary)
                        .fontDesign(.serif)
                }
                
                HStack {
                    Text("Biological Sex")
                        .fontDesign(.serif)
                    Spacer()
                    Text(user.biologicalSexString ?? "N/A")
                        .foregroundStyle(.secondary)
                        .fontDesign(.serif)
                }
                
                HStack {
                    Text("Resting Heart Rate")
                        .fontDesign(.serif)
                    Spacer()
                    Text(user.restingHeartRate != nil ? "\(Int(user.restingHeartRate!)) bpm" : "N/A")
                        .foregroundStyle(.secondary)
                        .fontDesign(.serif)
                }

                if healthFieldsEditable {
                    HStack {
                        Text("Max Heart Rate (bpm)")
                            .fontDesign(.serif)
                        Spacer()
                        TextField("e.g., 180", text: $maxHRString)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .fontDesign(.serif)
                            .disabled(isLoading) // Optionally disable while loading parent
                    }
                } else {
                    HStack {
                        Text("Max Heart Rate")
                            .fontDesign(.serif)
                        Spacer()
                        Text(user.maxHeartRate != nil ? "\(Int(user.maxHeartRate!)) bpm" : "N/A")
                            .foregroundStyle(.secondary)
                            .fontDesign(.serif)
                    }
                }

                if healthFieldsEditable {
                    HStack {
                        Text("Weight (\(unitSystem == .metric ? "kg" : "lbs"))")
                            .fontDesign(.serif)
                        Spacer()
                        TextField(unitSystem == .metric ? "e.g., 70.5" : "e.g., 155.5", text: $weightString)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .fontDesign(.serif)
                            .disabled(isLoading) // Optionally disable
                    }
                } else {
                    HStack {
                        Text("Weight")
                            .fontDesign(.serif)
                        Spacer()
                        Text(formattedWeight(user.weight))
                            .foregroundStyle(.secondary)
                            .fontDesign(.serif)
                    }
                }
                
                if healthFieldsEditable {
                    HStack {
                        Text("Height (\(unitSystem == .metric ? "cm" : "ft, in"))")
                            .fontDesign(.serif)
                        Spacer()
                        TextField(unitSystem == .metric ? "e.g., 175" : "e.g., 5' 9\"", text: $heightString)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(unitSystem == .metric ? .numberPad : .default)
                            .fontDesign(.serif)
                            .disabled(isLoading) // Optionally disable
                    }
                } else {
                    HStack {
                        Text("Height")
                            .fontDesign(.serif)
                        Spacer()
                        Text(formattedHeight(user.height))
                            .foregroundStyle(.secondary)
                            .fontDesign(.serif)
                    }
                }

                if !healthFieldsEditable && !isLoading { // Only show if not editable AND not loading
                    Text("Health data synced from Apple Health. To edit Weight, Height, or Max HR, please update directly in the Health app.")
                        .font(.caption)
                        .fontDesign(.serif)
                        .foregroundStyle(.secondary)
                        .padding(.top, 5)
                }
            }
        }
        .onAppear {
            // Initial string update if not loading
            if !isLoading {
                updateLocalStringsFromUserModel()
            }
        }
        .onChange(of: unitSystem) { _, _ in
            if !isLoading { updateLocalStringsFromUserModel() }
        }
        .onChange(of: user.weight) { _, _ in
            if !healthFieldsEditable && !isLoading { updateLocalStringsFromUserModel() }
        }
        .onChange(of: user.height) { _, _ in
            if !healthFieldsEditable && !isLoading { updateLocalStringsFromUserModel() }
        }
        .onChange(of: user.maxHeartRate) { _, _ in
            if !healthFieldsEditable && !isLoading {
                updateLocalStringsFromUserModel()
            }
        }
        .onChange(of: healthKitManager.isAuthorized) { _, _ in
            // This might re-trigger updates when loading finishes if isAuthorized changes
            if !isLoading { updateLocalStringsFromUserModel() }
        }
        .onChange(of: isLoading) { _, newIsLoading in
            if !newIsLoading {
                // Data has finished loading, update local strings
                updateLocalStringsFromUserModel()
            }
        }
    }
    
    private func updateLocalStringsFromUserModel() {
        if let weightKg = user.weight, !weightKg.isNaN {
            if unitSystem == .imperial {
                let weightLbs = weightKg * 2.20462
                weightString = String(format: "%.1f", weightLbs)
            } else {
                weightString = String(format: "%.1f", weightKg)
            }
        } else {
            weightString = ""
        }
        
        if let heightMeters = user.height, !heightMeters.isNaN {
            if unitSystem == .imperial {
                let totalInches = heightMeters * 39.3701
                let feet = Int(totalInches / 12)
                let inches = Int(round(totalInches.truncatingRemainder(dividingBy: 12)))
                heightString = "\(feet)' \(inches)\""
            } else {
                let heightCm = heightMeters * 100
                heightString = String(format: "%.0f", heightCm)
            }
        } else {
            heightString = ""
        }
        
        if let maxHr = user.maxHeartRate, !maxHr.isNaN {
            maxHRString = "\(Int(maxHr))"
        } else {
            maxHRString = ""
        }
        print("[HealthMetricsSectionView] Updated local strings from user model. Editable: \(healthFieldsEditable)")
    }

    private func formattedWeight(_ weightKg: Double?) -> String {
        guard let weightKg, !weightKg.isNaN else { return "N/A" }
        if unitSystem == .imperial {
            let weightLbs = weightKg * 2.20462
            return String(format: "%.1f lbs", weightLbs)
        } else {
            return String(format: "%.1f kg", weightKg)
        }
    }

    private func formattedHeight(_ heightMeters: Double?) -> String {
        guard let heightMeters, !heightMeters.isNaN else { return "N/A" }
        if unitSystem == .imperial {
            let totalInches = heightMeters * 39.3701
            let feet = Int(totalInches / 12)
            let inches = Int(round(totalInches.truncatingRemainder(dividingBy: 12)))
            return "\(feet)' \(inches)\""
        } else {
            let heightCm = heightMeters * 100
            return String(format: "%.0f cm", heightCm)
        }
    }
}

#if DEBUG
struct HealthMetricsSectionView_Previews: PreviewProvider {
    @MainActor static var previews: some View {
        _HealthMetricsSectionView_PreviewWrapper()
    }
}

struct _HealthMetricsSectionView_PreviewWrapper: View {
    @State private var weight: String = "150.5"
    @State private var height: String = "5' 10\""
    @State private var maxHR: String = "185"
    @State private var previewUser: User

    init() {
        let user = User(appleUserId: "previewUser", name: "John Doe", biologicalSexString: "Male")
        user.age = 30
        user.weight = 75.0
        user.height = 1.80
        user.restingHeartRate = 60.0
        user.maxHeartRate = 190.0
        _previewUser = State(initialValue: user)
    }

    var body: some View {
        let container = PersistenceController.previewContainer
        container.mainContext.insert(previewUser)

        return Form {
            HealthMetricsSectionView(
                user: previewUser,
                themeColor: Color(hex: "#929000") ?? .blue,
                weightString: $weight,
                heightString: $height,
                maxHRString: $maxHR,
                isLoading: false
            )
            .environmentObject(HealthKitManager.shared)
        }
        .modelContainer(container)
    }
}

struct PersistenceController {
    @MainActor static var previewContainer: ModelContainer = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: User.self, configurations: config)
            return container
        } catch {
            fatalError("Failed to create preview model container: \(error)")
        }
    }()
}
#endif
