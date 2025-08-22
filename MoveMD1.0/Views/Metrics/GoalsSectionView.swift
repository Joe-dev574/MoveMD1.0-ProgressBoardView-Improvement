import SwiftUI
import SwiftData

struct GoalsSectionView: View {
    @Bindable var user: User
    let fitnessGoals: [String] // Pass the array of goals
    var themeColor: Color

    var body: some View {
        Section {
            Picker("Fitness Goal", selection: Binding(
                get: { user.fitnessGoal ?? "General Fitness" }, // Provide a default if nil for the binding
                set: { user.fitnessGoal = $0 }
            )) {
                ForEach(fitnessGoals, id: \.self) { goal in
                    Text(goal)
                        .font(.system(size: 15, weight: .regular, design: .serif))
                }
            }
            .pickerStyle(.menu)
            .font(.system(size: 15, weight: .regular, design: .serif))
            .foregroundStyle(.primary)
            .accessibilityIdentifier("goalPicker")
        } header: {
            Text("Goals")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(themeColor)
        }
    }
}
